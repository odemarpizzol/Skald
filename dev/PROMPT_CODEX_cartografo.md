# Arte da aba Cartógrafo: prompt pronto para colar no Codex

A aba mostra os mapas desenhados em miniatura (colorida onde o personagem já esteve, esmaecida onde não). Faltam três peças pequenas para ela parecer um álbum. Anexe `output/map-art/contact-sheet.jpg` (acabamento dos mapas) e um print da aba, se tiver, e `Textures/skald2/map_corner.tga`, `map_compass.tga` e `rule.tga` (o traço dos ornamentos que já existem).

**O Codex só entrega a arte e os TGAs**, em `Textures/skald2/`. Não deve mexer em nenhum `.lua` nem em testes: eu ligo no código (como nos mapas de instância).

```
Continue o trabalho de arte do Skald (addon de World of Warcraft, um diário épico em forma de livro de couro). Faça TRÊS peças para a nova aba "Cartógrafo", que mostra os mapas desenhados em uma grade, como um álbum. Mesmo estilo dos mapas e dos ornamentos já existentes (veja os anexos): tinta marrom escura com hachuras finas, lavados de aquarela leves, ouro velho em pequenos detalhes, luz do alto à esquerda, SEM nenhuma letra ou número, fundo transparente, cerca de 8% de folga em cada lado (nada encostando na borda).

1. CARIMBO DE "PERCORRIDA" (map_stamp): um selo de tinta, como um carimbo de cera ou de tinta vermelha-escura aplicado à mão, que marca uma terra onde o personagem já esteve. Desenho: uma pegada de bota dentro de um pequeno círculo duplo com ornamento de folhas (sem letras). Cor: vermelho-tinta desgastado (o mesmo vinho do título das páginas, #6E1F1A), levemente irregular, como carimbado. Deve ficar legível quando reduzido a uns 28 px.
   Formato: PNG com alfa, 128 x 128 px.

2. MOLDURA DE MINIATURA (map_thumb_frame): uma moldura fina de álbum para uma miniatura de mapa 2:1: duas linhas de tinta paralelas e finas, cantos com pequenos ornamentos de folha e ouro velho (como o map_corner, só que nos QUATRO cantos já desenhados), o interior TOTALMENTE transparente (o mapa aparece por baixo). Nada de fundo.
   Formato: PNG com alfa, 512 x 256 px, o interior livre em uma área de 2:1 centrada que ocupa 88% da largura e 88% da altura.

3. SELO DO TÍTULO (map_title_seal): um pequeno emblema para ficar ao lado do cabeçalho "Cartógrafo": uma bússola aberta sobre um pergaminho enrolado, em tinta e ouro velho, no mesmo acabamento dos emblemas das Metas (Textures/pt_title*.tga).
   Formato: PNG com alfa, 128 x 128 px, o desenho ocupando no máximo 86% da área.

Entrega:
- PNGs em output/map-art/ (mande também versões 4x maiores para conferir).
- Converta cada um em TGA 32 bits SEM compressão (tipo 2), no tamanho em px acima (todos potência de 2), em Textures/skald2/map_stamp.tga, map_thumb_frame.tga e map_title_seal.tga. NÃO deixe PNG dentro de Textures/.
- Rode node dev/tools/checks.js e me diga o resultado (ele só confere se os TGAs citados no código existem; como eu ainda não liguei nada, ele deve passar sem mudança).
- NÃO altere nenhum arquivo .lua nem dev/tools.
```

## Depois que o Codex terminar (eu faço)

- Ligar o carimbo ao canto das miniaturas percorridas (só nas coloridas), a moldura por cima de cada miniatura e o selo ao lado do título.
- Conferir no jogo com `/skald perf` o passo `section cartographer`.
