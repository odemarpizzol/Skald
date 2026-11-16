# Prompts de arte: momentos novos (por um fio, resumo de masmorra, fogueira, duelo, PvP no mundo)

As páginas novas já funcionam com ícones que existem e foram emprestados (nada inventado foi posto no addon):

| Página (`kind`) | Ícone emprestado hoje | Ícone próprio pedido |
|---|---|---|
| `closecall` (por um fio) | `ev_revive` (ankh) | `ev_closecall` |
| `recap` (resumo da masmorra) | `ev_dungeon` (porta) | `ev_recap` |
| `campfire` (fogueira) | `st_camp` | `ev_campfire` |
| `duel` (duelo) | `ev_bg` (estandartes) | `ev_duel` |
| `wpvp` (PvP no mundo) | `ev_bg` (estandartes) | `ev_wpvp` |

Anexe como referência os PNG de `docs/reader/img/`: `ev_revive.png`, `ev_dungeon.png`, `ev_bg.png`, `ev_boss.png` e `st_camp.png`.

## Estilo (vale para os cinco)

Ícone de evento para um diário de World of Warcraft (addon Skald), no **mesmo estilo exato** dos anexos:

- pintura digital com aparência de ícone de jogo, não plana: metal com reflexo especular, madeira e couro com volume, pedra com textura, como a porta de `ev_dungeon` e o ankh de `ev_revive`;
- contorno escuro fino (marrom quase preto) em volta de toda a silhueta;
- luz vindo do alto à esquerda, com brilho forte no metal e sombra suave à direita e embaixo;
- paleta: ouro velho, aço azulado, madeira e couro marrons, vermelho-escuro; um só detalhe de cor forte por ícone (uma chama laranja, um tecido vermelho);
- sem texto, sem fundo, sem moldura, sem sombra projetada fora do desenho;
- legível em 20 a 28 px na página do livro: uma silhueta simples e forte, poucos elementos.

**Formato de cada um:** PNG com fundo transparente, **64 x 64 px**, o desenho ocupando no máximo 84% da área (cerca de 8% de folga livre em cada borda; nada encostando na borda). Mande também uma versão de 256 x 256 px com as mesmas proporções, para conferir os detalhes.

---

## Prompt 1: `ev_closecall.png` (uma luta vencida por um fio)

Um coração de rubi lapidado, rachado ao meio por uma fissura fina, preso por um fio de ouro que o envolve e o mantém inteiro. Uma única gota vermelho-escura escorrendo da rachadura. Enquadramento centrado, a silhueta compacta como o ankh de `ev_revive`.

## Prompt 2: `ev_recap.png` (o resumo de uma passagem por masmorra)

Um portão de masmorra de pedra em arco, como o de `ev_dungeon`, mas com as folhas de madeira **fechadas** e uma tranca de ferro atravessada; pendurada na tranca, uma pequena chave de ouro velho. Sem tocha (para não confundir com `ev_dungeon`). Enquadramento centrado.

## Prompt 3: `ev_campfire.png` (uma fogueira na estrada)

Uma fogueira de acampamento: três ou quatro toras cruzadas sobre um círculo de pedras, uma chama laranja viva e duas faíscas subindo, uma panelinha de ferro pendurada num tripé de galhos sobre o fogo. Silhueta larga e baixa, centrada.

## Prompt 4: `ev_duel.png` (um duelo)

Duas espadas de lâmina de aço azulado cruzadas em X, os punhos de couro com guarda de ouro velho, e uma bandeirinha de duelo (um pequeno pendão triangular vermelho-escuro com borda dourada) presa no ponto em que as lâminas se cruzam. Sem estandartes grandes (para não confundir com `ev_bg`).

## Prompt 5: `ev_wpvp.png` (outro jogador derrubado no mundo aberto)

Um elmo amassado caído de lado sobre um pequeno tufo de grama, com uma flecha de penas vermelho-escuras cravada no chão ao lado. Sem brasões de facção. Silhueta compacta, centrada, como o elmo de `ev_boss`.

---

## Depois que os PNG chegarem (para quem for ligar no código)

1. Converter para TGA 32 bits com `sharp`, sem mudar o tamanho (64 x 64), em `Textures/`; copiar os PNG também para `docs/reader/img/`.
2. `Skald.lua`, `K.EVENT_ICON`: `closecall = "closecall", recap = "recap", campfire = "campfire", duel = "duel", wpvp = "wpvp"` (e apagar o comentário "pictures of their own still to be drawn").
3. `Atlas.lua`, `GLYPH`: o mesmo, se o medalhão do mapa deve mostrar o ícone próprio (o filtro do mapa usa a chave do glifo: acrescentar os nomes em `UI_TEXT.*.KIND` e em `KIND_ORDER`).
4. `docs/reader/reader.js`, `KIND_ICON`: `closecall: 'ev_closecall'`, `recap: 'ev_recap'`, `campfire: 'ev_campfire'`, `duel: 'ev_duel'`, `wpvp: 'ev_wpvp'`.
5. Rodar `node dev/tools/checks.js` (confere que toda textura citada existe). Textura nova só aparece no jogo depois de reiniciar o jogo por completo, não com `/reload`.
