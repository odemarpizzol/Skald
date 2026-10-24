# Prompt para o Claude Design: rabiscos do personagem no fim do dia

Cole no Claude Design com as imagens de referência: o mockup "Diário de Jornada" (a fogueira, a espada, o mapa do tesouro e o pergaminho pequeno da página direita) e os rabiscos de clima já prontos (`wxd_*`), que são o estilo aprovado.

---

Preciso de **10 rabiscos** para o espaço em branco no fim das páginas do diário do addon Skald (World of Warcraft). Cada um mostra algo que aconteceu naquele dia, e deve parecer **desenhado à mão pelo próprio personagem**, com pena e tinta, no mesmo estilo dos rabiscos de clima e do mockup que anexei.

**Estilo (igual ao dos rabiscos de clima):**
- traço de nanquim marrom-escuro (quase preto-café), fino a médio, **levemente trêmulo, como feito à mão**;
- hachuras curtas para volume e sombra, sem preenchimento chapado;
- **sem aro, sem moldura, sem fundo**: só o desenho solto;
- aguada leve (aquarela) em um ou dois pontos do desenho, só onde ajuda: a chama em laranja-âmbar, a lâmina em cinza-azulado, e assim por diante;
- sem texto, sem sombra projetada, sem textura de papel (fundo **transparente**);
- legível em 48 a 72 px na tela, sobre papel claro e também sobre papel manchado.

**Formato:** PNG com fundo transparente, 128 x 128 px (potência de dois), o desenho ocupando no máximo 84% da área (cerca de 8% de folga livre em cada borda, nada encostando na borda).

**Rabiscos (nome do arquivo: o que aconteceu no dia):**
1. `dd_camp`: **Fogueira**. Troncos cruzados com chamas e uma fagulha. (descansou, acampou, voltou para casa)
2. `dd_sword`: **Espada**. Uma espada reta com a ponta para cima e um pequeno brilho na lâmina. (lutou, venceu um chefe, entrou numa masmorra)
3. `dd_map`: **Mapa do tesouro**. Um pergaminho dobrado com um caminho pontilhado e um marcador de posição. (descobriu terras novas)
4. `dd_scroll`: **Pergaminho pequeno**. Um rolo de papel enrolado, aberto na ponta, como o do mockup. (missão cumprida)
5. `dd_skull`: **Caveira**. Uma caveirinha simpática, de traço leve, com dois ossos cruzados por baixo. (morreu)
6. `dd_boots`: **Botas**. Um par de botas de viagem gastas, com um pouco de poeira. (viagem longa, voo)
7. `dd_paw`: **Pata**. Uma pegada de animal com quatro dedos e uma almofada. (ganhou um companheiro)
8. `dd_mug`: **Caneca**. Uma caneca de cerveja com espuma transbordando. (taverna, descanso)
9. `dd_star`: **Estrela**. Uma estrela de cinco pontas com raios curtos ao redor, traço firme. (subiu de nível)
10. `dd_anvil`: **Bigorna**. Uma bigorna com um martelo e uma fagulha. (ofício, profissão)

Mantenha os dez como uma família: mesma mão, mesmo peso de traço, mesma quantidade de hachura e de aguada. Eles vão aparecer sozinhos, soltos na página, então cada um precisa funcionar bem sem nada em volta.

Entregue cada rabisco em PNG separado, com esses nomes, mais uma folha única com os 10 lado a lado, uma vez sobre papel claro e uma vez sobre papel manchado, para eu conferir a consistência.

---

Quando você mandar o zip, eu converto para TGA 32 bits (128 x 128), escolho no código qual rabisco entra em cada dia (o desenho que mais combina com o que aconteceu), coloco no espaço vazio no fim da página e rodo `checks.js`. Textura nova exige reiniciar o jogo por completo.
