# Demon Fall Canyon: acrescentar o subsolo à planta

Hoje `Textures/skald2/map_demon_fall_canyon.tga` (ID 2784) mostra só o cânion e a entrada da gruta. O Codex avisou que faltou o subsolo por falta de referência confiável. Este prompt pede o mapa completo, no mesmo formato da Karazhan Crypts (vários pisos numa só imagem).

**Anexe:** `output/forever-art/map_demon_fall_canyon.png` (o atual), `map_karazhan_crypts.png` (como exemplo de vários pisos numa imagem) e uma ou duas plantas clássicas (Scholomance, Sunken Temple).

**Referência:** peça ao Codex para buscar a planta REAL do subsolo (mapa oficial da instância no cliente, guia da Icy Veins, Wowhead ou Keystone.guru) antes de desenhar. Se não achar uma referência confiável do subsolo, NÃO inventar: parar e dizer o que faltou.

```
Atualize o mapa da instância Demon Fall Canyon do Skald (addon de World of Warcraft). Hoje o arquivo mostra só o cânion e a entrada da gruta (anexado). Refaça a planta COMPLETA: o cânion em cima e o SUBSOLO (a gruta e as câmaras de baixo) numa só imagem, como fizemos com a Karazhan Crypts (anexada), com cada piso separado, sem desenhar um em cima do outro.

REFERÊNCIA: antes de desenhar, ache a planta REAL do subsolo de Demon Fall Canyon (mapa oficial da instância, Icy Veins, Wowhead, Keystone.guru) e use-a só como base da disposição das salas, túneis, plataformas e do caminho entre o cânion e o subsolo. Redesenhe tudo no nosso traço, sem decalcar. Se NÃO achar uma referência confiável do subsolo, não invente salas: pare e me diga exatamente o que faltou. Diga qual referência usou.

ESTILO: o mesmo das plantas que já existem (anexadas): PLANTA vista de cima, tinta marrom escura com hachuras finas e lavados leves de aquarela, luz do alto à esquerda. Rocha e terreno em volta esmaecem até o transparente. SEM nenhum texto, letra ou número; sem moldura. Pequenos detalhes (braseiros demoníacos, runas, pontes de pedra, plataformas) dão vida; nada de rótulos.

FUNDO (importante): ALFA REAL. Fora da planta, o fundo é totalmente transparente: nada de branco, papel, mancha, sombra quadrada ou degradê. Deixe cerca de 6% de folga nas bordas e centralize.

FORMATO: PNG com alfa, proporção 2:1, 1024 x 512 px. Salve em output/forever-art/map_demon_fall_canyon.png (substitui o atual; guarde o antigo como map_demon_fall_canyon_antigo.png).

Entregue só o PNG (sem TGA: eu converto) e diga a referência usada.
```

## Depois que o PNG chegar
1. Converto para TGA 32 bits, 512×256, com alfa, e substituo `Textures/skald2/map_demon_fall_canyon.tga`.
2. Rodo o `checks.js` e copio para o Forever. O ID (2784) e os nomes já estão ligados, então não há mudança de código.
