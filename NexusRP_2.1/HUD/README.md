# NexusRP — HUD

HUD customizado (vida, colete, fome, sede, voz, velocímetro e gasolina). Substitui o
painel de stats que antes era desenhado dentro do resource LOGIN.

## Instalação

1. Coloque a pasta `HUD` dentro de `resources`, junto com `LOGIN`.
2. No console do servidor:

```
refresh
start HUD
```

3. Para iniciar automaticamente, adicione no `mtaserver.conf`:
   `<resource src="HUD" startup="1" protected="0" />`

Não precisa rodar antes ou depois do LOGIN — os dois se sincronizam sozinhos via
`call()`/exports (`nexusHud_setActive` no HUD, `nexusHud_getState` no LOGIN). Se o HUD
for reiniciado sozinho com jogadores já na cidade, ele pergunta o estado atual ao LOGIN
no próprio `onClientResourceStart`.

## Integração com o NexusRP

- **Vida e colete**: dados nativos (`getElementHealth`/`getPedArmor`), sempre reais.
- **Dinheiro**: o componente nativo `money` do MTA **não é escondido** — este HUD não
  desenha um substituto para o saldo, então o valor nativo (real) continua visível.
- **Fome e sede**: leem `elementData` `cyber_fome`/`cyber_sede` do jogador
  (configurável em `config.lua`). O NexusRP ainda não tem esses sistemas, então as
  barras ficam sempre cheias até algo começar a setar esses valores.
- **Gasolina**: lê `elementData` `fuel` do veículo. Sem sistema de combustível no
  NexusRP ainda, o medidor aparece sempre cheio.
- **Voz**: reage aos eventos nativos de voicechat. Se o voicechat estiver desligado no
  servidor, o ícone só fica sempre semi-transparente — sem erro.
- **Radar/arma/munição/relógio/procurado**: ficam escondidos (estilo minimalista do
  HUD). Se quiser manter o radar nativo visível, remova `"radar"` da lista
  `hiddenComponents` em `client.lua`.

## Personalização

`config.lua`: nomes dos `elementData` usados pelo HUD.
`client.lua`: desenho do HUD e lista de componentes nativos escondidos.
`circle/`: shader do velocímetro/medidor de gasolina (arco).
