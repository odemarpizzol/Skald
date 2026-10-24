# Prompts para o Claude Design: desgaste, nota de margem, fita e selos de cera

Cole cada bloco separado no Claude Design, com as imagens de referência (a capa do livro, `b_parchment`, `b_quill`, os selos `seal1` a `seal5` e o mockup "Melhorias de Jornada e História").
Estilo comum a todos: o do addon (contorno marrom-escuro quase café, tons quentes de pergaminho, couro e ouro velho, sombreado suave, brilho pequeno no canto superior esquerdo, **um único detalhe de cor por peça**, sem texto no desenho, sem sombra projetada fora do desenho).

---

## Bloco A: papéis com desgaste (3 texturas)

Preciso de **3 texturas de página** para o livro do addon Skald (World of Warcraft), a mesma página de pergaminho em três graus de desgaste, para o jogador escolher (ou o diário envelhecer sozinho):

1. `paper_leve`: pergaminho limpo, quase novo, só uma leve variação de cor e bordas ligeiramente irregulares.
2. `paper_aventureiro`: manchas suaves de umidade e café, dobras discretas, cantos escurecidos, uma ou duas gotas de tinta.
3. `paper_batalha`: muito usado: manchas grandes escuras, respingos de tinta e de sangue seco (sem exagero), bordas queimadas ou rasgadas, vincos fundos. Ainda deve dar para ler texto por cima.

**Importante:** o miolo da página (onde o texto vai) deve ficar **legível e de contraste parecido nos três**; o desgaste vive mais nas bordas e em manchas. Mesma proporção, mesma área útil e mesmo enquadramento de `b_parchment`, para trocar uma pela outra sem mexer no layout.
**Formato:** PNG com fundo transparente, no mesmo tamanho de `b_parchment` (potência de dois), 8% de folga nas bordas.

---

## Bloco B: nota de margem e pena (2 peças)

1. `note_sticky`: um pedaço de papel pequeno, torto, preso por um selo de cera vermelho pequeno no canto superior direito, com espaço vazio no meio para o jogador escrever (o texto é do addon). Bordas irregulares, uma dobra no canto. Formato horizontal de 256 x 256 px.
2. `note_quill`: uma pena de escrever inclinada, com uma assinatura rabiscada em tinta saindo da ponta (rabisco abstrato, **sem palavras legíveis**). Serve de ícone para "adicionar nota". 128 x 128 px.

PNG transparente, 8% de folga nas bordas.

---

## Bloco C: fita marcadora e selos de cera (4 peças)

1. `ribbon_mark`: uma fita de seda vinho pendurada, terminada num medalhão de bronze com um símbolo simples de livro aberto (ou de espiral), como o do mockup. Vertical, 128 x 256 px (sim, uma potência de dois de cada lado), a fita sai por cima da borda do desenho.
2. `waxseal_horde`: selo de cera vermelho-escuro, gota irregular, com o brasão da Horda gravado em relevo (um relevo, sem cor extra).
3. `waxseal_alliance`: selo de cera azul-real, mesma forma e mesmo tamanho, com o leão da Aliança em relevo.
4. `waxseal_neutral`: selo de cera marrom-vinho, mesma forma, com um **X** gravado em relevo (neutro, para pandaren sem facção e raças que mudam de lado).

Os três selos precisam ser uma família: mesmo contorno de gota, mesmo brilho, mesmo relevo, só a cor e o emblema mudam. 128 x 128 px, PNG transparente, 8% de folga.

---

Entregue cada peça em PNG separado, com esses nomes, mais uma folha única por bloco para eu conferir a consistência.

Quando você mandar o zip, eu converto para TGA 32 bits (potência de dois), ligo no código (opção de desgaste, nota de margem na página, fita na última página lida, selo pela facção na capa) e rodo `checks.js`. Textura nova exige reiniciar o jogo por completo.
