# Arte da aba PvP (Crônica de Guerra): prompt pronto para colar no Codex

A aba lista os campos de batalha: totais, vitórias e derrotas por campo e as últimas partidas. Faltam três peças pequenas. Anexe `Textures/skald2/map_title_seal.tga`, `map_stamp.tga` e `map_corner.tga` (o acabamento dos emblemas do Cartógrafo, que é o mais recente), e um print das Metas, se tiver (`Textures/pt_title*.tga`).

**O Codex só entrega a arte e os TGAs**, em `Textures/skald2/`. Não deve mexer em nenhum `.lua` nem em testes: eu ligo no código.

```
Continue o trabalho de arte do Skald (addon de World of Warcraft, um diário épico em forma de livro de couro). Faça TRÊS peças para a nova aba "Crônica de Guerra" (PvP), que conta os campos de batalha do personagem. Mesmo estilo dos emblemas já existentes (veja os anexos): tinta marrom escura com hachuras finas, lavados de aquarela leves, ouro velho em pequenos detalhes, luz do alto à esquerda, SEM nenhuma letra ou número, fundo transparente, cerca de 8% de folga em cada lado (nada encostando na borda). O tom é de guerra antiga e sóbria, não de videogame: sem sangue, sem caveiras, sem brilho de neon.

1. SELO DO TÍTULO (pvp_title_seal): um pequeno emblema para ficar ao lado do cabeçalho "Crônica de Guerra": duas espadas cruzadas sobre dois estandartes de pano pendurados (um deles ligeiramente vermelho-vinho, o outro azul-aço desbotado, sem símbolos de facção e sem letras), em tinta e ouro velho, no mesmo acabamento do map_title_seal.
   Formato: PNG com alfa, 128 x 128 px, o desenho ocupando no máximo 86% da área.

2. MARCA DE VITÓRIA (pvp_won): um pequeno selo para marcar uma partida vencida: um estandarte erguido, preso a uma haste reta, com uma coroa de louros curta ao pé. Ouro velho e um verde-musgo desgastado (cerca de #55702F) em lavado, contornos em tinta marrom. Deve ficar legível reduzido a uns 24 px.
   Formato: PNG com alfa, 64 x 64 px.

3. MARCA DE DERROTA (pvp_lost): o par do anterior, para uma partida perdida: o mesmo estandarte, mas tombado e rasgado, a haste partida, sem louros. Vermelho-vinho desgastado (o mesmo #6E1F1A do título das páginas) e marrom, sem ouro. Mesmo tamanho, traço e silhueta do anterior, para formarem um par. Deve ficar legível reduzido a uns 24 px.
   Formato: PNG com alfa, 64 x 64 px.

Entrega:
- PNGs em output/pvp-art/ (mande também versões 4x maiores para conferir).
- Converta cada um em TGA 32 bits SEM compressão (tipo 2), no tamanho em px acima (todos potência de 2), em Textures/skald2/pvp_title_seal.tga, pvp_won.tga e pvp_lost.tga. NÃO deixe PNG dentro de Textures/.
- Rode node dev/tools/checks.js e me diga o resultado (ele só confere se os TGAs citados no código existem; como eu ainda não liguei nada, ele deve passar sem mudança).
- NÃO altere nenhum arquivo .lua nem dev/tools.
```

## Depois que o Codex terminar (eu faço)

- Ligar o selo ao lado do título da aba, a marca de vitória e a de derrota na frente de cada partida das últimas partidas.
- Conferir no jogo com `/skald perf` o passo `section pvp`.
