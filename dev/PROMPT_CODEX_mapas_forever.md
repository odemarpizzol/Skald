# Mapas das terras novas do Forever: prompt pronto para colar no Codex

Três terras que o cliente do Forever tem e que não existem no Classic, vistas no `/skald report` de 2026-11-04: **Monte Hyjal** (ID 2482), **Shen'dralas** (ID 2652) e **Sendas do Rio** (ID 2548). Os IDs e os nomes vêm do próprio jogo. A Zephras Isle fica para depois, quando o Skyborne existir e o `/skald probe maps` der o ID dela.

**Antes de colar:** eu não conheço a geografia dessas terras e não vou inventar. Anexe **um print do mapa de cada terra no jogo** (abra o mapa-múndi, clique na terra e tire o print), e a folha de contato `output/map-art/contact-sheet.jpg` (os mapas que já existem, como referência de acabamento). O Codex deve usar o print só como referência da forma e da disposição, e redesenhar tudo no nosso traço.

**O Codex só entrega a arte e os TGAs**, em `Textures/skald2/`. Não deve mexer em nenhum `.lua` nem em testes: eu ligo no código (`ZC.ART`).

```
Continue o trabalho dos mapas do Índice do Skald (addon de World of Warcraft). Já existem os mapas de zona, de instância e de capital (veja a folha de contato anexa). Agora faça os 3 mapas das TERRAS NOVAS do Forever, no MESMO estilo, paleta e nível de acabamento daqueles. Cada terra tem um print do mapa do jogo anexo: use-o SÓ como referência da forma geral, dos rios, montanhas, lagos e marcos, e redesenhe tudo no nosso traço, sem decalcar.

ESTILO: gravura de mapa antigo em tinta marrom escura com hachuras finas e lavados de aquarela leves; luz do alto à esquerda; SEM nenhum texto, letra ou número; sem moldura: as bordas se dissolvem até o transparente, com cerca de 6% de folga; fundo transparente. A forma do contorno deve seguir o print, e cada terra deve ser reconhecível de relance.

FORMATO: PNG com alfa, proporção 2:1, 1024 x 512 px (revisão também em 2048 x 1024; coloque em output/map-art/1024 e output/map-art/2048).

AS 3 TERRAS (arquivo | nome | ID do mapa):
- map_hyjal | Mount Hyjal (Monte Hyjal) | 2482
- map_shendralas | Shen'dralas | 2652
- map_riverpaths | River Paths (Sendas do Rio) | 2548

DEPOIS DE DESENHAR (faça você mesmo, como nas levas de zona):
1. Converta cada PNG em TGA 32 bits SEM compressão (tipo 2), 512 x 256, em Textures/skald2/map_<nome>.tga. NÃO deixe PNG dentro de Textures/.
2. NÃO altere ZoneCard.lua nem nenhum outro .lua: eu acrescento as linhas em ZC.ART.
3. Rode node dev/tools/checks.js e me diga o resultado.
4. Atualize a folha de contato em output/map-art/contact-sheet.jpg (as terras novas em uma seção à parte).
```

---

## Depois que o Codex terminar (eu faço)

- Acrescentar `[2482] = "map_hyjal"`, `[2652] = "map_shendralas"` e `[2548] = "map_riverpaths"` em `ZC.ART` (ZoneCard.lua) e uma regressão no mesmo formato das de mapas anteriores.
- Esses mapas só existem no Forever. Fora dele o cartão não os mostra, e o Cartógrafo os deixa de fora da lista (ele pula o mapa que o cliente não tem). Nada quebra no Anniversary.
- Peso: ~+1,6 MB no addon.
