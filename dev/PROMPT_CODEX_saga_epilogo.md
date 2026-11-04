# Arte do Epílogo da Saga: prompt pronto para colar no Codex

A Saga termina hoje com o Epílogo espremido embaixo de "Selos e Renome" e uma página direita em branco. A ideia é dar ao Epílogo uma página própria, com uma ilustração grande de encerramento. Anexe `Textures/ui_saga_walker.tga`, `ui_saga_camp_horde.tga`, `ui_saga_scroll.tga` e `ui_saga_seals.tga` (o traço das ilustrações que já existem na Saga) e um print da Saga.

**O Codex só entrega a arte e o TGA**, em `Textures/`. Não deve mexer em nenhum `.lua` nem em testes: eu ligo no código e faço a quebra de página.

```
Continue o trabalho de arte do Skald (addon de World of Warcraft, um diário épico em forma de livro de couro). Faça UMA ilustração de encerramento para o Epílogo da Saga, no MESMO estilo das ilustrações da Saga já existentes (veja os anexos): gravura em tinta marrom escura com hachuras finas, lavados de aquarela leves, ouro velho em pequenos detalhes, luz do alto à esquerda, SEM nenhuma letra ou número, fundo transparente, bordas que se dissolvem até o transparente, cerca de 8% de folga (nada encostando na borda).

TEMA: uma estrada que some no horizonte. Uma trilha de terra que sai do primeiro plano e se afasta em perspectiva, entre algumas pedras, tufos de capim e uma árvore torta, até se perder em colinas suaves sob um céu aberto de fim de tarde (sem sol desenhado, só uma luz dourada no horizonte). No primeiro plano, perto de quem olha, uma única pena grande de escrever cravada no chão ao lado da trilha, como se o diário tivesse parado ali. Nenhuma pessoa. O clima é de "a história não acabou, só pausou onde a página termina": calmo, aberto, sem tristeza. O mesmo viajante de capuz e cajado da ilustração "walker" pode aparecer MUITO pequeno, de costas, bem longe na trilha, mas é opcional.

FORMATO: PNG com alfa, 512 x 512 px, o desenho ocupando no máximo 86% da área, com mais peso na metade de baixo (a ilustração fica sozinha numa página, abaixo de um título e de duas linhas de texto).

Entrega:
- PNG em output/saga-art/ (e uma versão 2x para conferir).
- Converta em TGA 32 bits SEM compressão (tipo 2), 512 x 512, em Textures/ui_saga_epilogue.tga. NÃO deixe PNG dentro de Textures/.
- Rode node dev/tools/checks.js e me diga o resultado (ele só confere se os TGAs citados no código existem; como eu ainda não liguei nada, ele deve passar sem mudança).
- NÃO altere nenhum arquivo .lua nem dev/tools.
```

## Depois que o Codex terminar (eu faço)

- Quebra de página antes do Epílogo (ele passa para a página da direita) e a ilustração abaixo do texto, centralizada.
- Conferir os três idiomas, o texto do Epílogo mais longo no francês e o Reader, que também exporta a Saga.
