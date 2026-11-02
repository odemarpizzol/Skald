# Prompts de arte: WoW Forever (branch `forever-launch`)

> **Feito (2026-11-02, pelo Codex) e já ligado no código:** `Textures/ev_bg.tga` (64x64), `Textures/skald2/dd_banner.tga` (128x128) e `docs/reader/img/ev_bg.png`. Os TGAs foram regravados sem compressão (como os outros 270 do addon) e os PNGs de trabalho ficam em `output/forever-art/` (fora do git). A página de campo de batalha usa agora `ev_bg` e o rabisco `banner`. Os passos "Depois que os PNG chegarem" abaixo já foram feitos.

Arte nova pedida pelas features do Forever. Hoje o código usa arte que já existe no lugar (o elmo `ev_boss` na página de campo de batalha, a espada `dd_sword` nos rabiscos). Nada inventado foi colocado no addon.

Anexe como referência: `Textures/ev_boss.tga`, `Textures/ev_goal.tga`, `Textures/st_flight.tga` (ou os PNG equivalentes em `docs/reader/img/`), e `Textures/skald2/dd_sword.tga` e `dd_camp.tga` para os rabiscos.

---

## Prompt 1: ícone de página "Campo de batalha" (`ev_bg`)

Preciso de **1 ícone** para um diário de World of Warcraft (addon Skald), no **mesmo estilo exato** dos ícones de evento que anexei (`ev_boss`, `ev_goal`, `st_flight`):

- pintura digital com aparência de ícone de jogo, não plana: metal com reflexo especular, couro e tecido com volume, tecido vermelho-escuro e ouro velho como no `ev_goal`;
- contorno escuro fino (marrom quase preto) em volta de toda a silhueta;
- luz vindo do alto à esquerda, com brilho forte no metal e sombra suave à direita e embaixo;
- paleta: ouro velho, aço azulado, vermelho-escuro, couro marrom; um só detalhe de cor forte;
- sem texto, sem fundo, sem moldura, sem sombra projetada fora do desenho;
- legível em 20 a 28 px na página do livro.

**Ideia:** dois estandartes de guerra cruzados em mastros de madeira com ponteira de metal: um vermelho-escuro (Horda) e um azul-escuro (Aliança), sem os brasões oficiais (só um padrão simples, como uma faixa dourada). Atrás deles, a ponta de uma espada ou uma trompa de guerra. Enquadramento centrado, a silhueta no formato de um X largo, como o elmo do `ev_boss` ocupa o quadro.

**Formato:** PNG com fundo transparente, **64 x 64 px**, o desenho ocupando no máximo 84% da área (cerca de 8% de folga livre em cada borda; nada encostando na borda). Mande também uma versão de 256 x 256 px com as mesmas proporções, para eu conferir os detalhes.

Nome do arquivo: `ev_bg.png`.

---

## Prompt 2 (opcional): rabisco "estandarte" para o pé do dia (`dd_banner`)

Preciso de **1 rabisco** para a margem das páginas do diário, no **mesmo estilo exato** dos rabiscos que anexei (`dd_sword`, `dd_camp`):

- o mesmo acabamento pintado e brilhante, o mesmo contorno escuro e a mesma luz do alto à esquerda;
- paleta: ouro velho, madeira, tecido vermelho-escuro;
- sem texto, sem fundo, sem sombra projetada.

**Ideia:** um único estandarte de guerra fincado no chão, o tecido ondulando ao vento, um pequeno tufo de grama na base. Silhueta alta e estreita, como a espada do `dd_sword`.

**Formato:** PNG com fundo transparente, **128 x 128 px**, cerca de 8% de folga livre em cada borda (o desenho dentro de uns 108 x 108 px no centro).

Nome do arquivo: `dd_banner.png`.

---

## Depois que os PNG chegarem (para quem for ligar no código)

1. Converter para TGA 32 bits com `sharp`, sem mudar o tamanho (potência de dois): `ev_bg.tga` em `Textures/`, `dd_banner.tga` em `Textures/skald2/`. Copiar `ev_bg.png` também para `docs/reader/img/`.
2. `Skald.lua`, `K.EVENT_ICON`: trocar `bg = "boss"` por `bg = "bg"` e apagar o comentário "until a battleground icon...".
3. Se houver `dd_banner`: em `K.DOODLE_OF` trocar `bg = "sword"` por `bg = "banner"` e pôr `"banner"` em `K.DOODLE_ORDER` (logo depois de `"sword"`).
4. `docs/reader/reader.js`, `KIND_ICON`: trocar `bg: 'ev_boss'` por `bg: 'ev_bg'`.
5. Rodar `node dev/tools/checks.js` (ele confere que toda textura citada no código existe). Textura nova só aparece no jogo depois de reiniciar o jogo por completo, não com `/reload`.
