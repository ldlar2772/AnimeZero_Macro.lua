# AnimeZero Macro

**GGM HUB | ANIME ZERO - V38**

O arquivo principal é [`ggmHub.Lua`](https://github.com/ldlar2772/AnimeZero_Macro.lua/blob/main/ggmHub.Lua). Ele cria uma interface Rayfield com três abas: **Combate**, **Waypoints** e **Personagem**.

## Funcionalidades

- **Auto Farm:** procura inimigos vivos e automatiza o movimento até eles e os ataques.
- **Auto Quebrar Barreira:** percorre waypoints gravados, procura objetos identificados como barreiras e os ataca quando não há inimigos vivos.
- **Waypoints:** grava posições e permite salvar, carregar e apagar rotas em arquivos JSON separados por `PlaceId`.
- **Auto Replay/Lobby:** ao detectar a tela final, tenta acionar o botão de repetir ou sair, conforme a opção selecionada.
- **Combate:** simula ataques básicos e o uso das habilidades 1, 2, 3 e ultimate, com intervalo configurável.
- **Personagem:** oferece controles para WalkSpeed, NoClip e HipHeight.

## Dependências e compatibilidade

O código carrega Rayfield pela internet e usa APIs específicas de executor, como `getgenv`, `VirtualInputManager`, `writefile` e `readfile`. Por isso, depende de um executor e não roda diretamente no Roblox Studio padrão.
