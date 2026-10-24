# Prompt para o Claude Design: rabiscos de clima, desenhados "pelo personagem"

Cole no Claude Design com as imagens de referência: o mockup "Diário de Jornada" (os rabiscos do sol, da nuvem de chuva, do floco de neve, da fogueira, da espada e do mapa) e, só para a paleta do papel, `b_parchment`.
Isto **substitui** o prompt dos carimbos redondos (`PROMPT_ARTE_clima.md`): os carimbos com aro de couro não combinam com o desenho do diário.

---

Preciso de **6 rabiscos de clima** para as páginas do diário do addon Skald (World of Warcraft). A ideia: parecem **desenhados à mão pelo próprio personagem**, com pena e tinta, nas margens do diário, no mesmo estilo dos rabiscos do mockup que anexei.

**Estilo (siga o mockup à risca):**
- traço de nanquim marrom-escuro (quase preto-café), fino a médio, **levemente trêmulo, como feito à mão**, sem linhas perfeitas;
- hachuras curtas para dar volume e sombra, sem preenchimento chapado;
- **sem aro, sem moldura, sem fundo, sem borda**: só o desenho solto, como se estivesse direto no papel;
- um toque leve de aguada (aquarela) por rabisco, por dentro do traço e um pouco para fora dele, como o mockup: o sol em amarelo-ouro, a chuva em azul-acinzentado, a neve em azul-gelo pálido;
- sem texto, sem sombra projetada, sem textura de papel (o papel é do livro: o fundo é **transparente**);
- legível em 56 a 72 px na tela, sobre papel claro e também sobre papel manchado.

**Formato:** PNG com fundo transparente, 128 x 128 px (potência de dois), o desenho ocupando no máximo 84% da área (cerca de 8% de folga livre em cada borda, nada encostando na borda).

**Rabiscos (nome do arquivo: ideia):**
1. `wxd_sun`: **Calor**. Um sol redondo com raios curtos e longos desenhados com traços soltos. Aguada amarelo-ouro.
2. `wxd_rain`: **Chuva**. Uma nuvem cheia, com cinco a sete gotas riscadas embaixo. Aguada azul-acinzentada na nuvem.
3. `wxd_snow`: **Neve**. Um floco de neve de seis pontas, com ramificações simples. Aguada azul-gelo pálida.
4. `wxd_sand`: **Tempestade de areia**. Faixas de vento em espiral, com pontinhos de areia e uma duna ao fundo. Aguada ocre.
5. `wxd_fog`: **Névoa**. Três faixas onduladas sobrepostas e, atrás delas, a silhueta de uma árvore seca. Aguada cinza-esverdeada.
6. `wxd_storm`: **Tempestade**. Uma nuvem escura, riscada com hachuras densas, e um raio em zigue-zague. Aguada amarelo-pálida só no raio.

Mantenha os seis como uma família: mesmo peso de traço, mesma mão, mesma quantidade de hachura e de aguada.

Entregue cada rabisco em PNG separado, com esses nomes, mais uma folha única com os 6 lado a lado, uma vez sobre papel claro e uma vez sobre papel manchado, para eu conferir a consistência.

---

Quando você mandar o zip, eu converto para TGA 32 bits (128 x 128), troco os carimbos de aro pelos rabiscos na página do dia e rodo `checks.js`. Textura nova exige reiniciar o jogo por completo.
