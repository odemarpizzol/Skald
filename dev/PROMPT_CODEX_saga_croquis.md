# Croquis dos três capítulos da Saga que estão sem desenho: prompt pronto para colar no Codex

Na Saga, quatro capítulos têm um croqui de tinta ao lado do texto (o acampamento, o viajante, o pergaminho com a pena e os selos). Faltam três: **Tronos Derrubados** (`war`), **As Quedas** (`falls`) e **Companhia** (`company`). Anexe `Textures/ui_saga_camp_horde.tga`, `ui_saga_walker.tga`, `ui_saga_scroll.tga` e `ui_saga_seals.tga` (o traço exato dos croquis que já existem) e um print da Saga.

**O Codex só entrega a arte e os TGAs**, em `Textures/`. Não deve mexer em nenhum `.lua` nem em testes: eu ligo no código.

```
Continue o trabalho de arte do Skald (addon de World of Warcraft, um diário épico em forma de livro de couro). Faça TRÊS croquis pequenos para capítulos da Saga que ainda não têm desenho, no MESMO estilo, traço, paleta e peso visual dos quatro croquis existentes (veja os anexos): tinta marrom escura com hachuras finas, lavados leves em sépia e ouro velho em pequenos detalhes, luz do alto à esquerda, uma pequena base de chão em tinta que se dissolve até o transparente (como o acampamento e o viajante), SEM nenhuma letra ou número, fundo transparente, cerca de 8% de folga em cada lado. O objeto deve ter o MESMO tamanho aparente dos croquis existentes (nem maior nem mais cheio): o croqui do pergaminho já é o mais pesado, não passe dele.

1. TRONOS DERRUBADOS (ui_saga_war): um trono de pedra e madeira tombado de lado sobre o chão, com uma coroa de ouro velho rolada ao lado e uma espada partida cravada ao pé. Sem sangue e sem corpos. Sobriedade de fim de batalha.

2. AS QUEDAS (ui_saga_falls): um escudo de madeira e ferro caído e meio enterrado no chão, rachado ao meio, com um elmo amassado ao lado e uma pequena pena tombada sobre ele. Sem sangue e sem caveiras. Sobriedade, quase ternura: quem cai se levanta.

3. COMPANHIA (ui_saga_company): uma mesa pequena e redonda de taberna vista em leve perspectiva, com uma lanterna acesa no centro, duas canecas de madeira, um pão partido e três banquinhos ao redor, um deles meio afastado, como se alguém tivesse acabado de se levantar. Sem pessoas. Calor, não tristeza.

FORMATO: PNG com alfa, 256 x 256 px cada, o desenho ocupando no máximo 86% da área.

Entrega:
- PNGs em output/saga-art/ (e versões 4x para conferir).
- Converta cada um em TGA 32 bits SEM compressão (tipo 2), 256 x 256, em Textures/ui_saga_war.tga, ui_saga_falls.tga e ui_saga_company.tga. NÃO deixe PNG dentro de Textures/.
- Rode node dev/tools/checks.js e me diga o resultado (ele só confere se os TGAs citados no código existem; como eu ainda não liguei nada, ele deve passar sem mudança).
- NÃO altere nenhum arquivo .lua nem dev/tools.
```

## Depois que o Codex terminar (eu faço)

- Acrescentar `war`, `falls` e `company` à tabela `SKETCH` de `Saga.lua`. O texto passa a ter a coluna estreita ao lado do croqui, como nos outros, e a estimativa de altura da página já considera isso.
- Conferir que três capítulos com croqui ainda cabem por página e rodar os testes da Saga.
