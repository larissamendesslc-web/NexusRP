# NexusRP 2.1 — Login, recepção e HUD

## Instalação

1. Guarde uma cópia da pasta LOGIN anterior fora de resources.
2. No console do servidor: `stop LOGIN`.
3. Extraia este ZIP e substitua a pasta resources/LOGIN pela pasta LOGIN do pacote.
   Não deixe resources/LOGIN/LOGIN. Não apague o banco interno do MTA.
4. Se o modo padrão play estiver ativo, execute `stop play` para ele não controlar
   seleção de personagem/spawn junto do NexusRP.
5. Execute, um comando por vez:

```
refresh
aclrequest allow LOGIN function.addAccount
start LOGIN
```

6. Reconecte ao servidor e entre com sua conta existente.

Para iniciar automaticamente, mantenha em mtaserver.conf:
`<resource src="LOGIN" startup="1" protected="0" />`
Desative o startup de play caso esteja usando somente o NexusRP.

## O que entrou

- NPC Alex perto do spawn no aeroporto, com identificação flutuante e interação E.
- Recepção automática de quatro etapas no primeiro acesso após esta atualização.
- Botões Continuar, Voltar, Pular e Começar minha história.
- Backspace fecha o tutorial e marca como visto. /tutorial permite rever a qualquer hora,
  estando vivo e fora de um veículo. Pular/concluir não concede dinheiro nem teleporta.
- HUD roxo: nome, ID persistente da conta, saldo real do MTA, vida, colete e localização.
- Radar, armas e munição continuam disponíveis no HUD nativo.
- Posição, rotação, interior, dimensão, dinheiro, vida e colete são salvos a cada
  60 segundos, ao sair, ao deslogar e ao parar o resource normalmente.
- Próximo login recupera o último estado salvo. Conta sem estado salvo nasce no aeroporto.
- Mortes usam um respawn provisório no aeroporto após 5 segundos. Não é um sistema de hospital.
- Música, cadastro e login anteriores mantidos; texto de entrada não promete mais
  aeroporto para contas que possuem posição salva.
- Permissão específica addAccount incluída no meta.xml e função de HUD atualizada.

## Personalização

config.lua: nome/cor da tela de login, skins iniciais e spawn.
welcome_config.lua: posição/skin do NPC, falas e intervalo de salvamento.
city_client.lua: desenho e cores do HUD/diálogo em DX nativo do MTA.
city_server.lua: persistência e estado de tutorial.

A interface de login continua em CEF. A recepção e o HUD usam DX para esta etapa.
Não há cutscene, GPS/rota, empregos, inventário, fome/sede, hospital ou economia de lojas.
A persistência de dinheiro acompanha o saldo nativo; não cria uma moeda separada.
Veículos, armas e inventário ainda não são persistidos. Ao reconectar, o jogador
volta a pé à posição salva. Uma queda abrupta pode perder até um intervalo de autosave.

## Teste no MTA

1. Entrar com a conta existente: deve aparecer a recepção uma única vez.
2. Concluir as quatro telas: cursor deve sumir, personagem deve andar e HUD continuar.
3. Usar /tutorial e fechar com Backspace; repetir usando Pular.
4. Aproximar do Alex no aeroporto e pressionar E.
5. Andar para outro local, desconectar normalmente e entrar de novo: conferir posição.
6. Reiniciar LOGIN conectado: não deve teleportar nem repetir tutorial já concluído.
7. Se necessário, consultar server.log e usar debugscript 3 no F8 com permissão.

## Validação desta entrega

- Sintaxe Lua com parser 5.4 e JavaScript com Node verificadas.
- Manifesto XML, arquivos e solicitação de permissão verificados.
- Testes Lua com APIs do MTA simuladas cobrem persistência, logout, valores do jogador,
  origem inválida de evento, tutorial persistente, sync repetido, respawn, execução
  do desenho de HUD/diálogo, conclusão, Backspace e limpeza ao parar.
- Não executado no MTA/CEF real; desenho, NPC e integração com outros resources
  precisam do teste local descrito acima. Os testes simulados não substituem isso.

Referências das APIs:
https://wiki.multitheftauto.com/wiki/SetAccountData
https://wiki.multitheftauto.com/wiki/GetAccountID
https://wiki.multitheftauto.com/wiki/OnPlayerLogout
https://wiki.multitheftauto.com/wiki/SetPlayerHudComponentVisible
