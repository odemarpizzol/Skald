# Prompt de arte: o que o cliente do TBC (Anniversary) pede

Hoje só há uma peça. Até ela chegar, a página de Joalheria usa o ícone geral dos ofícios (`ev_profession`), sem quadrado branco: o código só pede `pf_<profissão>` para as 12 que têm arte (`K.PF_ICONS` em `Skald.lua`).

Anexe como referência: `Textures/pf_alchemy.tga`, `pf_enchanting.tga` e `pf_blacksmithing.tga` (ou PNGs deles).

---

## Ícone da profissão Joalheria (`pf_jewelcrafting`)

Preciso de **1 ícone** para o addon Skald (diário de World of Warcraft), no **mesmo estilo exato** dos ícones de profissão que anexei (`pf_alchemy`, `pf_enchanting`, `pf_blacksmithing`):

- pintura digital com cara de ícone de jogo, não plana: metal com reflexo especular, vidro e pedra com brilho, volume e luz forte vindo do alto à esquerda, sombra suave à direita e embaixo;
- contorno fino em marrom escuro quase preto em volta de toda a silhueta;
- paleta: ouro velho e bronze nos metais, tons de pergaminho e couro quando houver, e **um único destaque forte de cor** (como o roxo da gema do `pf_enchanting` e o verde do frasco do `pf_alchemy`);
- sem texto, sem fundo, sem moldura, sem sombra projetada fora do desenho;
- legível em 20 a 28 px na página do livro.

**Ideia:** uma gema lapidada, de muitas facetas, em azul-safira ou vermelho-rubi, presa por garras de ouro e apoiada em uma pequena lupa de joalheiro (ou ao lado dela). A gema é o destaque de cor; o ouro faz o resto. Enquadramento centrado, a silhueta ocupando o quadro como a poção e o cajado dos outros ícones.

**Formato:** PNG com fundo transparente, **64 x 64 px**, o desenho ocupando no máximo 84% da área (cerca de 8% de folga em cada borda; nada encostando na borda). Mande também uma versão de 256 x 256 px, com as mesmas proporções, para conferir os detalhes.

Nome do arquivo: `pf_jewelcrafting.png`.

---

## Depois que o PNG chegar

1. Converter para TGA 32 bits **sem compressão** (tipo 2, como os outros 270 do addon; um TGA com RLE destoa do resto) e salvar em `Textures/pf_jewelcrafting.tga`.
2. `Skald.lua`, `K.PF_ICONS`: acrescentar `jewelcrafting = true` e apagar o comentário "waits for its picture" se houver.
3. Rodar `node dev/tools/checks.js`.
4. Textura nova só aparece depois de **reiniciar o jogo por completo**, não com `/reload`.
