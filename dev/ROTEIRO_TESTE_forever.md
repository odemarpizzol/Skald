# Roteiro de teste, Skald: branch `forever-launch` no Anniversary

Marque cada passo com **pronto** ou **falhou** (com print, o texto do erro e o que você fez). Cada passo diz o que esperar.
Lembrete: os testes automáticos são uma simulação, não o jogo; só vale o que for visto aqui.

O Anniversary **não é** o Forever: ele não esconde valores dos addons e não tem a raça Skyborne. Por isso este roteiro testa três coisas:
1. que as mudanças da branch **não quebraram** nada que já funcionava (chefes, loot, mapa da zona);
2. o que **dá** para ver aqui: campos de batalha, metas novas, terra natal na Saga (com Draenei ou Elfo Sangrento) e o `/skald probe events`;
3. as partes das versões 0.41 a 0.43 que **ainda não foram vistas** no jogo: Busca, Bardo, Backup e Configurações.

Ordem sugerida: Fase 0, depois A, B e C (são as novidades). D a G se sobrar tempo. Total de 1h30 a 2h, fora a fila de campo de batalha.

---

## Fase 0: instalar (10 min)
1. No seu clone local (WSL), traga a branch:
   ```bash
   git fetch origin forever-launch && git checkout forever-launch
   ```
2. Faça a cópia simulada para o jogo (o `-n` só lista o que mudaria):
   ```bash
   D="/mnt/d/Games/World of Warcraft/_anniversary_/Interface/AddOns/Skald"
   rsync -rcn --itemize-changes --exclude=.git --exclude=.github --exclude=.gitignore --exclude=.pkgmeta --exclude=.claude --exclude=dev --exclude=docs --exclude=CLAUDE.md --exclude=README.md --exclude=CHANGELOG.md --exclude=LICENSE ./ "$D/"
   ```
   Se a lista fizer sentido (Lua e o TOC), rode de novo sem o `-n`, e depois:
   ```bash
   sed -i "s/^## Interface:.*/## Interface: 20506/" "$D/Skald.toc"
   ```
3. Antes de abrir o jogo, **faça backup** de `WTF\Account\<conta>\SavedVariables\Skald.lua` e dos `Skald.lua` dentro das pastas de personagem. O teste B usa um personagem novo, mas nunca se sabe.
4. Abra o jogo (não há textura nova: um jogo recém-aberto basta) e entre com o seu personagem principal.
5. `/skald`. **Esperado:** o livro abre, sem erro no chat. Se aparecer erro, mande o texto inteiro, e também o de `/skald report`.

---

## Fase A: metas novas e o que não pode ter quebrado (15 min)
**A1. Metas da versão 5**
1. Aba **Feitos**, categoria **Guerra**. **Esperado:** a lista tem agora 3 páginas (`1 de 3`) e as setas dos cantos vão até a 3 e voltam.
2. Procure as três metas novas: "Primeiro Sangue no Campo", "Uma Vida de Estandartes", "O Livro do Senhor da Guerra" (texto: "Campos de batalha vencidos: %d."). **Esperado:** nomes e textos sem código solto (`%d`, `{g:`), com 0 de 1 / 10 / 50.
3. **Esperado:** nenhuma página nova de meta e nenhum aviso aparece só por ter entrado no jogo (as metas novas entram em silêncio).

**A2. Chefe** (masmorra baixa ou chefe de mundo, o que for mais fácil)
1. Mate um chefe. **Esperado:** página de chefe como antes, sem erro no chat.
2. Se morrer antes, **esperado:** a página do chefe fala das quedas, como antes.

**A3. Loot**
1. Pegue um item verde ou melhor (ou fabrique algo). **Esperado:** página de item como antes.

**A4. Mapa da zona (Índice, página direita)**
1. Abra o **Índice** numa zona com missões. **Esperado:** mapa da zona, regiões, missões "feitas de total" e criaturas, como antes. Anote os números para comparar com o B3.

---

## Fase B: terra natal na Saga, com personagem novo (15 min)
Draenei e Elfo Sangrento **não existem no Forever**: aqui eles são só substitutos do Skyborne. A Saga tem a terra natal escrita à mão para as 8 raças antigas; qualquer outra raça (o Skyborne no Forever, Draenei e Elfo Sangrento no Anniversary) passa pelo código novo, que guarda o mapa onde o personagem nasceu. Se funcionar com eles aqui, o caminho do Skyborne está certo; só o nome da raça fica para conferir no dia 04.

**B1. Criar o personagem**
1. Crie um **Draenei** ou **Elfo Sangrento** (qualquer classe) e entre. Fique parado uns **15 segundos** na área inicial.
2. `/dump SkaldCharDB.birthMap`. **Esperado:** um número (o mapa da zona inicial). Se vier `nil`, mande print e diga quanto tempo esperou.

**B2. Saga**
1. Faça uma ou duas missões e abra a aba **Saga**. **Esperado:** o primeiro capítulo diz que você nasceu na sua zona inicial, "em Kalimdor" (Draenei) ou "nos Reinos do Leste" (Elfo Sangrento), com os nomes que o próprio jogo usa, sem código solto.
2. Antes desta branch, essas raças abriam a Saga sem lugar de nascimento ("Prólogo"). Se ainda abrir assim, mande print.

**B3. Mapa da zona com raça nova**
1. Índice na zona inicial. **Esperado:** o total de missões faz sentido (não é 0 nem absurdo). Se tiver o QuestDB, anote o total.

**B4. Idioma**
1. Se puder, entre com o cliente em inglês (ou francês) e repita o B2. **Esperado:** "Azuremyst Isle, in Kalimdor" e texto correto.

---

## Fase C: campos de batalha (30 a 45 min, com fila)
O Anniversary tem Garganta Brado Guerreiro, Bacia Arathi, Vale Alterac e Olho da Tormenta. Arena **não** conta.

**C1. Ligar o probe antes de entrar na fila**
1. `/skald probe events`. **Esperado:** mensagem "contando todos os eventos do cliente...".

**C2. Uma partida**
1. Jogue uma partida até o fim (vitória ou derrota, tanto faz).
2. No placar final, **esperado:** em poucos segundos aparece **um** aviso de "Campo de batalha" e uma página nova.
3. Abra o livro. **Esperado:**
   - a página diz o nome do campo e combina com o resultado. Vitória: "Vitória em ...", "Tomamos ...", "Nossa bandeira...". Derrota: "Derrota em ...", "ficou com o outro lado...";
   - **uma** página só por partida, mesmo ficando no placar um tempo;
   - o ícone é o dos dois estandartes cruzados (um vermelho, um azul), com a ponta de lança dourada. Esta arte é nova: **reinicie o jogo por completo** antes de testar, `/reload` não basta. Se aparecer um quadrado branco ou o elmo, me avise;
4. Se venceu: aba **Feitos** → Guerra. **Esperado:** "Primeiro Sangue no Campo" cumprida, com página de meta e aviso de pontos.
5. Se der, jogue uma **segunda** partida (de preferência com resultado diferente). **Esperado:** outra página, com o texto do resultado certo.

**C3. Fora do campo**
1. Depois de sair, passeie um pouco. **Esperado:** nenhuma página de campo de batalha a mais.

**C4. Busca**
1. Aba **Busca**, filtro **Batalhas**. **Esperado:** as páginas de campo de batalha aparecem na lista; o clique abre a página.

**C5. O que o probe ouviu**
1. `/skald probe events list`. **Esperado:** uma lista com nomes como `UPDATE_BATTLEFIELD_STATUS xN` e outros com PVP ou BATTLEFIELD. Mande um print da lista: é exatamente isso que vamos fazer no Forever para achar os eventos de acampamento e Legacy.
2. `/reload` e de novo `/skald probe events list`. **Esperado:** o probe continua ligado e a contagem sobe.
3. `/skald probe events off`. **Esperado:** "contagem de eventos parada". Deixe desligado depois do teste.

---

## Fase C2: a voz nova "Da minha gente" (10 min)
1. Aba **Configurações** → página **Estilo**. **Esperado:** quatro vozes em duas linhas (Da minha gente, Épico, Humilde, Bem-humorado), nada cortado; o seu personagem principal continua na voz que tinha.
2. Escolha **Da minha gente**. **Esperado:** a dica e o exemplo mudam; volte ao livro e as páginas de nível antigas agora falam sem número ("Estou mais forte do que era...", na voz da sua raça).
3. Suba um nível (ou use um personagem perto disso). **Esperado:** a página não tem número, e a cada dez níveis vem uma frase de marco ("Uma estação da minha vida se fecha..."). A página de meta não diz "+10 pontos".
4. O personagem novo da Fase B (Draenei ou Elfo Sangrento) já nasce nessa voz, se for a primeira instalação do Skald na conta; senão, escolha à mão. **Esperado:** as frases de nível são as gerais da voz (essas raças não têm frases próprias).
5. Leia algumas frases da sua raça e diga se soam fiéis à lore. É a parte mais importante deste teste.
6. Volte para a voz que você usava, se quiser. **Esperado:** os números voltam às páginas antigas.

## Fase D: Busca (10 min, nunca vista no jogo)
1. Aba **Busca**, digite uma palavra de uma missão que você lembra. **Esperado:** a lista aparece um instante (cerca de um quarto de segundo) depois de parar de digitar, com a palavra pintada e as mais novas primeiro.
2. Digite sem acento ou em maiúsculas (por exemplo, "VALE" para "Vale"). **Esperado:** acha do mesmo jeito.
3. Teste os filtros (tipo, favoritas, até quando). **Esperado:** a lista diminui conforme o filtro; só uma lista suspensa aberta por vez.
4. Clique numa linha. **Esperado:** o livro vai para a página certa.

---

## Fase E: Bardo (10 min, nunca ouvido no jogo)
1. Aba **Bardo**, clique numa música. **Esperado:** toca, o relógio conta e as notinhas aparecem perto da lareira.
2. Próxima, anterior e **Aleatório**. **Esperado:** troca de música; com Aleatório, "anterior" volta pelo que tocou.
3. Mexa no volume. **Esperado:** a música do jogo muda de volume (e o volume da música nas opções do jogo também).
4. Feche o livro com a música tocando. **Esperado:** aparece o aviso na tela com o nome da música; arraste-o e veja que ele lembra o lugar depois de um `/reload`.
5. Deixe uma música chegar ao fim. **Esperado:** a próxima começa sozinha.
6. Anote as músicas que **não tocam** (silêncio): no Forever algumas podem faltar, e aqui também.

---

## Fase F: Backup e Configurações (15 min, nunca vistos no jogo)
**Use o personagem novo da Fase B.**
1. `/skald backup`. **Esperado:** janela com o texto em partes; copie todas para um bloco de notas.
2. Escreva uma nota num dia (tinteiro) para mudar o diário.
3. `/skald restore`, cole as partes (em qualquer ordem) e confirme. **Esperado:** o diário volta a ser o do backup (a nota do passo 2 some) e o livro mostra isso na hora.
4. `/skald restore undo`. **Esperado:** a nota do passo 2 volta.
5. Aba **Configurações**: vire as três páginas pelos cantos (Estilo, Avisos, Opções). **Esperado:** nada sobreposto ou cortado. Troque o visual das abas (couro, fita, latão, pergaminho, madeira) e o papel das páginas. Mande print de qualquer coisa torta.

---

## Fase G: olhada geral (5 min)
1. `/skald report`: copie e guarde (é a referência do Anniversary para comparar com o Forever no dia 04).
2. Algum erro no chat em qualquer momento? Mande o texto inteiro.
3. Frases que soaram estranhas (em qualquer idioma): mande o print. Elas entram na revisão de idioma.

---

## O que **não** dá para testar no Anniversary (fica para o dia 04, no Forever)
- frases do Skyborne (as da Horda falam dos espíritos do vento e da visão do céu; as da Aliança, do arcano e de Eldre'Thalas) e o nome interno da raça;
- valores escondidos pelo cliente (chefe e loot em luta): aqui só conferimos que nada quebrou (A2, A3);
- leitura da reputação pela API nova (`C_Reputation`);
- eventos de acampamento e de Legacy (com o `/skald probe events`);
- o ícone de campo de batalha no Leitor web: o site só muda quando a branch for publicada.
