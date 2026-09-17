# NexusRP — Arquitetura do Core (proposta)

Documento de referência oficial para o padrão de UX e a arquitetura técnica de todos
os sistemas construídos a partir daqui. Não descreve código ainda implementado — é o
plano acordado antes de começar a construir.

## 1. Padrão de UX

- Interfaces importantes (inventário, banco, loja, garagem, celular) em CEF/HTML/CSS/JS.
  Nada de `guiCreateWindow`/GUI nativa da MTA para essas telas.
- Interação sempre física no mapa: o jogador anda até um ponto, vê um prompt discreto
  `[E] <ação>` (mesmo padrão já usado com o Alex), aperta E, o painel CEF abre.
- Transições suaves (fade/slide, nunca troca abrupta), fundo do jogo escurecido/borrado
  quando um painel está aberto.
- Identidade visual própria do NexusRP (cores, tipografia, ícones) — as referências de
  FiveM (ESX/QBCore-style) servem só de régua de qualidade/organização, não de
  branding a copiar.
- Nenhum sistema crítico confia no cliente: todo saldo, item, veículo e compra é
  calculado e validado no servidor. O cliente só manda "eu quero fazer X"; quem decide
  se X é válido e aplica o efeito é sempre o server.

## 2. Visão geral

```
                        ┌────────────┐
                        │   LOGIN    │  (autenticação MTA, intacto)
                        └─────┬──────┘
                              │ nexusAuth:onPlayerAuthenticated (já existe, não muda)
                              ▼
                        ┌────────────┐
                        │    CORE    │  banco de dados, sessão do personagem,
                        │            │  dinheiro, exports centrais
                        └─────┬──────┘
              ┌───────────────┼────────────────┬─────────────┬─────────────┐
              ▼               ▼                ▼             ▼             ▼
          INVENTORY        BANK            NEEDS         VEHICLES       (futuro)
          (itens/peso)   (carteira/         (fome/sede)   (dono/combustível/
                          banco)                           lataria/motor)
              │                                                │
              ▼                                                ▼
            SHOPS ──────────────────────────────────────── GARAGES
         (catálogo físico)                          (retirar/guardar/vagas)

          UIKIT (design system CEF compartilhado) e
          INTERACT (pontos físicos [E] reutilizáveis)
          são usados por todos os resources com painel.

          PHONE entra por último, integrando com BANK/GARAGES/etc.
```

Cada caixa acima é um **resource MTA separado**, seguindo o mesmo padrão que já
estabelecemos com HUD: comunicação entre resources só por `export`/`call()`, nunca
por globais soltos ou side-channel. `CORE` é o único que fala com o banco de dados;
todo o resto pede dados a ele por export.

**Ponto de integração com o que já existe:** `LOGIN/server.lua` já dispara
`triggerEvent("nexusAuth:onPlayerAuthenticated", player, account, {name, age, sex, skin})`
quando o personagem é autenticado. Esse evento não é restrito a handlers dentro do
próprio resource — qualquer resource pode dar `addEventHandler` nele sem precisar
mudar uma linha do LOGIN. `CORE` vai escutar exatamente esse evento pra carregar/criar
a linha do personagem. Ou seja, o core se encaixa no que já existe sem tocar em LOGIN.

## 3. Banco de dados

Hoje o LOGIN usa contas nativas da MTA + `setAccountData` com um blob JSON
(`nexus.cityState`) pra posição/dinheiro/vida/colete. Isso funciona bem pro que existe
hoje (só isso), mas não escala pra inventário com slots, transações bancárias,
propriedade de veículo, vagas de garagem etc. — juntar tudo isso em blobs JSON dentro
de account data vira uma dor de cabeça rapidamente (sem query, sem índice, sem
integridade referencial).

**Proposta:** `CORE` abre seu próprio banco via `dbConnect`, começando em **SQLite**
(zero infraestrutura extra, arquivo local, já nativo do MTA) com queries escritas de um
jeito (sempre parametrizadas com `?`, sem SQL específico de um dialeto) que permite
trocar pra MySQL depois só mudando o `dbConnect` — sem reescrever lógica — quando/se o
servidor crescer a ponto de precisar.

O saldo em dinheiro do MTA (`getPlayerMoney`/`setPlayerMoney`) deixa de ser a fonte da
verdade; passa a ser só um **espelho visual** do campo `cash` no banco (é inclusive o
que o HUD atual já lê nativamente — ele continua funcionando, só passa a refletir um
valor que agora é setado pelo CORE em vez de crescer sozinho).

### Tabelas propostas

**`characters`** — 1 linha por personagem (chave estrangeira pro `account_id` nativo
da MTA, o mesmo que o LOGIN já usa)
- `id`, `account_id`, `name`, `sex`, `age`
- `cash`, `bank`
- `position_x/y/z/rotation/interior/dimension`, `health`, `armor`
- `tutorial_done`, `created_at`, `last_seen_at`

**`bank_transactions`** — auditoria de tudo que mexe em dinheiro
- `id`, `character_id`, `type` (deposit/withdraw/transfer/purchase/salary/…),
  `amount`, `balance_after`, `meta` (json livre), `created_at`

**`item_definitions`** — não é bem "dado de jogador", é conteúdo estático. Proposta:
viver como **config Lua versionado no git** (fácil de revisar/balancear em PR), não
como tabela — só carregado em memória no start do resource.
- `id`, `label`, `description`, `weight`, `stackable`, `max_stack`, `type`
  (weapon/food/drink/document/misc), `usable`, `effects` (nome de handler chamado
  ao usar), `shop_price`, `image`

**`inventory_items`** — o que cada personagem realmente tem
- `id`, `character_id`, `item_id` (refere `item_definitions`), `slot`, `quantity`,
  `metadata` (json — ex.: munição de uma arma, validade de uma comida, número de
  série de um documento)

**`vehicles`**
- `id`, `character_id` (dono), `model`, `plate` (único), `fuel`, `engine_health`,
  `body_health`, `color`/`mods` (json), `state` (out/garaged/impounded),
  `garage_id` (nullable), `spawn_point_id` (nullable — qual vaga da garagem ele
  ocupa agora, só preenchido quando `state = garaged` não faz sentido; quando
  `state = out`, guarda a posição atual em vez disso)
- `position_x/y/z/rotation/interior/dimension` (só relevante quando `state = out`)

**`garages`** — conteúdo semi-estático, mas com estado runtime (vagas ocupadas), então
fica em banco, não em config puro
- `id`, `name`, `type` (public/residential/job/impound), `interaction_x/y/z`,
  `spawn_points` (json: lista de `{id, x, y, z, rotation}`), `owner_ref` (nullable,
  pra residencial/corporação no futuro)

**`shops`** — majoritariamente conteúdo estático (posição + catálogo), pode ficar em
config Lua igual `item_definitions`, só migra pra banco se um dia quisermos estoque
dinâmico (não precisa agora).

> Tabelas de **celular** (contatos, mensagens, apps) ficam de fora por enquanto — só
> reservamos o character_id como chave pronta pra quando entrarmos nesse módulo.

## 4. Resources propostos

Seguindo a convenção que já existe (`LOGIN/`, `HUD/`: `meta.xml` + `config.lua` +
`server.lua`/`client.lua` + `html/`), nomes em maiúsculo:

| Resource | Responsabilidade | Depende de |
|---|---|---|
| `CORE` | Conexão com banco, sessão do personagem, dinheiro, exports centrais, bootstrap de item_definitions | LOGIN (evento, sem alterá-lo) |
| `UIKIT` | Design system CEF compartilhado: CSS/JS/fontes/ícones, gerenciador de painel (abrir/fechar, blur/dim, freeze, cursor), tokens de cor/animação | — |
| `INTERACT` | Sistema genérico de pontos físicos `[E]`: registra ponto, raio, texto do prompt; desenha o prompt discreto; valida distância também no server antes de qualquer ação | CORE (opcional, pra revalidar quem está logado) |
| `BANK` | UI de carteira/banco físico (ATM) e transferências | CORE, UIKIT, INTERACT |
| `INVENTORY` | Grid, peso, ações de item (usar/dropar/dar), drag&drop | CORE, UIKIT |
| `NEEDS` | Fome/sede: decaem com o tempo, itens consumíveis restauram. Já tem onde plugar: o HUD que fizemos lê `elementData` `cyber_fome`/`cyber_sede` — este resource passa a setar esses valores de verdade | CORE, INVENTORY |
| `VEHICLES` | Modelo de dados de veículo: dono, combustível, vida do motor/lataria, spawn/despawn autoritativo | CORE |
| `SHOPS` | Pontos físicos de loja + catálogo CEF + fluxo de compra validado no server | CORE, INVENTORY, UIKIT, INTERACT |
| `GARAGES` | Pontos físicos + painel CEF (lista, busca, favoritos, preview, retirar/guardar) + alocação de vaga | CORE, VEHICLES, UIKIT, INTERACT |
| `PHONE` | Smartphone CEF full-screen, arquitetura de apps extensível | CORE, UIKIT, e o que mais quisermos integrar (BANK, GARAGES...) |

### Sobre "reutilizável" na prática da MTA

Duas coisas diferentes:
- **CEF/CSS/JS compartilhado é real**: qualquer painel pode carregar
  `http://mta/UIKIT/design-system.css` (a MTA serve os arquivos web de *todo* resource
  rodando, não só do local) — é assim que INVENTORY, BANK, SHOPS, GARAGES e PHONE vão
  todos parecer a mesma família de produto sem copiar CSS em cada um.
- **Lua não tem import entre resources**: lógica de servidor compartilhada vira
  **export** (`CORE` expõe `core_getCharacter`, `core_addMoney`, etc., os outros
  chamam via `call()` — o mesmo padrão que já usamos entre LOGIN e HUD).

## 5. UIKIT — o que ele resolve

Hoje já resolvemos isso uma vez, "na mão", pro LOGIN (freeze, esconder cursor, abrir
browser CEF, animação de fade). `UIKIT` generaliza esse padrão pra não reinventar em
cada painel novo:

- `openPanel(name, htmlPath, options)` / `closePanel(name)`: cria/reaproveita o
  browser, aplica fade/slide, foca o browser, trata cursor/freeze de forma
  consistente.
- Fundo escurecido: um retângulo `dxDraw` semi-transparente atrás do CEF já resolve
  "escurecimento" de forma barata e confiável. Um blur óptico de verdade da cena 3D
  exigiria capturar o backbuffer via shader — é possível na MTA, mas caro e frágil;
  a recomendação é começar com dim/escurecimento (que já cobre o efeito pedido) e só
  investigar blur de verdade depois, como polimento, não como bloqueio.
- Tokens de cor/tipografia num único CSS compartilhado, pra toda interface nascer
  com a mesma identidade (a que ainda vamos desenhar) sem depender de cada painel
  acertar sozinho.
- Biblioteca JS pequena pra abrir/fechar com animação e reportar eventos pro Lua
  (mesmo mecanismo `mta.triggerEvent` que a tela de login já usa).

## 6. INTERACT — pontos físicos reutilizáveis

Cada módulo (loja, garagem, ATM, futuro emprego) só declara:
```
{ x, y, z, radius = 2.5, label = "Acessar garagem", onTrigger = function(player) ... end }
```
`INTERACT` cuida de: desenhar o prompt discreto quando o jogador está perto (mesmo
estilo visual do prompt do Alex), escutar a tecla E, e — importante — **revalidar a
distância no servidor** antes de disparar `onTrigger`, porque a posição que o cliente
diz que tem não é confiável. Isso evita, por exemplo, abrir um painel de garagem ou
loja de longe via cliente modificado.

## 7. Especificação de GARAGENS (a única a detalhar agora)

Fluxo: jogador entra no raio do ponto de interação → prompt `[E] Acessar garagem` →
E → server revalida distância → server manda o estado atual (veículos do dono,
vagas livres daquela garagem) → CEF abre o painel.

Painel (dados que ele mostra, todos vindos do server, nunca calculados no cliente):
veículos do jogador, busca, favoritos, preview/imagem, modelo, placa, combustível,
motor, lataria, situação (na garagem / fora / apreendido), botões retirar/guardar.

Regras de negócio no servidor:
- **Retirar**: servidor pega a lista de `spawn_points` da garagem, filtra as que não
  estão ocupadas (nenhum veículo `state=out` com `spawn_point_id` == aquela vaga),
  deixa o jogador escolher entre as livres (nunca spawna em cima de vaga ocupada —
  isso mata o "empilhar carro").
- **Guardar**: só aceita se o veículo estiver fisicamente perto da garagem (raio
  maior, tipo 15-20m) e pertencer ao jogador; marca `state=garaged`, despawna,
  limpa posição.
- **Fora da garagem**: se o carro já está no mundo (em outro lugar), o painel mostra
  isso e não oferece "retirar" de novo — oferece talvez "localizar" no futuro.
- **Apreendido**: `state=impounded` — bloqueia retirar normalmente, fica reservado
  pra quando o módulo de apreensão existir (não implementar agora, só deixar o
  enum pronto).

Cada garagem no banco carrega seu próprio `interaction point` e sua própria lista de
`spawn_points` — já preparado pra existirem várias garagens (públicas, residenciais,
corporativas) sem mudar estrutura, só cadastrando linhas novas com `type` diferente.
Isso não será implementado agora — só a modelagem já fica pronta pra não retrabalhar.

## 8. Segurança — regras que valem pra todo módulo daqui pra frente

- Toda ação que muda dinheiro/item/veículo/estado é uma função **server-side**
  chamada por evento; o client nunca aplica o efeito, só pede.
- Todo preço/quantidade é recalculado a partir da config do servidor — nunca aceito
  como veio do cliente.
- Toda ação ligada a um ponto físico (comprar, guardar veículo, sacar dinheiro)
  revalida distância no server, não só no client.
- Toda mutação de dinheiro passa por uma função central do CORE (`addMoney`/
  `removeMoney`) que já grava em `bank_transactions` — nunca um módulo mexe direto
  no campo `cash`/`bank`.

## 9. Ordem de implementação proposta

1. **CORE** — banco (SQLite), tabela `characters`, sessão de personagem, exports de
   dinheiro (`getMoney`/`addMoney`/`removeMoney`), hook em
   `nexusAuth:onPlayerAuthenticated`. Sem isso nada mais tem onde guardar dado.
2. **UIKIT** — gerenciador de painel + design system, provado com um painel bem
   simples (ex.: só mostrar saldo) antes de construir qualquer coisa mais complexa
   em cima. Define a identidade visual do zero.
3. **INTERACT** — sistema de ponto físico `[E]`, genérico, sem UI própria.
4. **BANK** — primeiro painel "de verdade" ponta a ponta (CORE + UIKIT + INTERACT
   juntos), mais simples que inventário, valida o padrão inteiro antes de investir
   no que é mais trabalhoso.
5. **INVENTORY** — grid, peso, ações de item. O maior investimento de UI; só faz
   sentido depois do UIKIT provado.
6. **NEEDS** (fome/sede) — liga nos itens consumíveis do inventário e nas barras
   que o HUD já desenha hoje com fallback seguro.
7. **SHOPS** — pontos físicos + catálogo, usa INVENTORY (receber item) e CORE
   (pagar).
8. **VEHICLES** — modelo de dono/combustível/vida, spawn/despawn autoritativo,
   ainda sem painel bonito.
9. **GARAGES** — painel completo conforme a seção 7, em cima de VEHICLES.
10. **PHONE** — por último, porque ganha valor integrando com BANK (transferência
    pelo celular) e GARAGES (o que fizer sentido), então é mais barato construir
    depois que eles já existem.

Passos 6 e 7 podem trocar de ordem entre si sem problema (não dependem um do outro).
O resto tem dependência real na ordem acima.

## 10. Fora de escopo por enquanto

Garagens públicas/residenciais/corporativas e apreensão já têm campo/enum reservado
no modelo (`garages.type`, `vehicles.state`), mas a lógica de cada uma só entra
quando chegarmos nelas — não faz parte da primeira implementação de GARAGES.
