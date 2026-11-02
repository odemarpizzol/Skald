# Roteiro em tabelas: Draenei Paladino, cliente em português (branch `forever-launch`, Anniversary)

Como usar: marque a coluna **OK** com ✔ (deu certo), ✘ (falhou) ou ➖ (não deu para testar), e escreva em **Notas** o que viu. Para cada ✘, mande print e o texto inteiro de qualquer erro do chat.
Lembrete: os testes automáticos são uma simulação, não o jogo. Só vale o que for visto aqui.

**Por que um Draenei Paladino:** o Draenei não existe no Forever. Aqui ele faz o papel do **Skyborne**: é uma raça que a Saga não conhece, então passa pelo código novo da terra natal. O Paladino exercita as frases de classe (a Luz).

**Nomes em português que você vai ver:** Capa, Índice, Busca, Jornadas, Bardo, Feitos, Saga, Atlas, Ajustes (com três páginas: Estilo, Avisos, Opções).

---

## 0. Preparação (antes de entrar no jogo)

| # | Passo | Como fazer | Esperado | OK | Notas |
|---|---|---|---|:-:|---|
| 0.1 | Backup | Copie `WTF\Account\<conta>\SavedVariables\Skald.lua` e os `Skald.lua` das pastas de personagem | Cópia guardada fora do `WTF` | | |
| 0.2 | Cópia do addon | Já feita. Se o repositório mudou: `rsync` do roteiro anterior (com `--exclude=output`) | Nenhuma diferença na verificação com `-n` | | |
| 0.3 | Mudar o idioma | Battle.net → engrenagem ao lado de **Jogar** → configurações do jogo → idioma do texto: **Português (Brasil)**. Pode baixar arquivos de idioma | Jogo abre todo em português | | |
| 0.4 | Reiniciar por completo | Feche o jogo até o Windows e abra de novo (as texturas novas só carregam assim) | Sem erro ao abrir | | |
| 0.5 | Livro abre | No personagem principal: `/skald` | O livro abre em português, sem erro no chat | | |

## 1. O personagem principal em português (2 min)

As páginas guardam só números e o índice da frase, então o diário antigo deve ser **recontado em português**.

| # | Passo | Como fazer | Esperado | OK | Notas |
|---|---|---|---|:-:|---|
| 1.1 | Abas | Olhe a coluna de abas | Capa, Índice, Busca, Jornadas, Bardo, Feitos, Saga, Atlas, Ajustes | | |
| 1.2 | Páginas antigas | Aba **Jornadas**, abra um dia antigo | Textos em português; títulos de missão no idioma do jogo; **nada** em inglês misturado | | |
| 1.3 | Código solto | Olhe várias páginas | Nenhum `%s`, `%d`, `{g:`, `{name}` aparece no texto | | |

## 2. Criar o Draenei Paladino e o nascimento (15 min)

| # | Passo | Como fazer | Esperado | OK | Notas |
|---|---|---|---|:-:|---|
| 2.1 | Criar | **Draenei**, **Paladino**, qualquer sexo (anote qual: ____) | Personagem entra na Ilha Azuremyst (o nome em português é o que o jogo mostrar) | | |
| 2.2 | Aviso de diário novo | Veja o chat ao entrar | Se aparecer "outro personagem está usando este nome...", é porque o nome já foi usado. Isso é normal | | |
| 2.3 | Esperar | Fique **parado 15 segundos** na área inicial, sem subir de nível | (nada visível) | | |
| 2.4 | Mapa de nascimento | `/dump SkaldCharDB.birthMap` | Um **número** (não `nil`) | | |
| 2.5 | Nome do lugar | `/dump C_Map.GetMapInfo(SkaldCharDB.birthMap).name` | O nome do mapa da ilha, em português | | |
| 2.6 | Primeiras missões | Faça 2 ou 3 missões | Páginas de missão aparecem no livro | | |
| 2.7 | Saga | Aba **Saga** | O primeiro capítulo diz que você nasceu na ilha, "em Kalimdor"; **não** abre como "Prólogo" sem lugar | | |
| 2.7b | Artigo do lugar | Leia o primeiro capítulo da Saga e as páginas de zona e morte | "na Ilha Névoa Lazúli", "no Vale Ammen"; nunca "em Ilha Névoa Lazúli" nem o nome seco no começo da frase | | |
| 2.8 | Gênero | Leia o texto da Saga | Concordância certa com o sexo do personagem (por exemplo "um Draenei Paladino" ou "uma Draenei Paladina") | | |

## 3. A voz "Da minha gente" (10 min)

A voz é da **conta**: o novo personagem usa a que você escolheu por último. Esta etapa só muda **nível, marco de 10 níveis, terra nova e morte**. Missão, chefe e item continuam no tom de antes (esperado).

| # | Passo | Como fazer | Esperado | OK | Notas |
|---|---|---|---|:-:|---|
| 3.1 | Escolher a voz | **Ajustes → Estilo**, clique **Da minha gente** | Quatro vozes em duas linhas, nada cortado. Dica: "Sua gente e sua terra falam: sem números, sem pontos, só o mundo." | | |
| 3.2 | Exemplo | Olhe o exemplo abaixo | "Estou mais forte do que era. Os ancestrais olharam, e não desviaram o olhar." | | |
| 3.3 | Subir de nível | Chegue ao nível 2 e depois ao 3 | Páginas de nível **sem número**, com frases gerais da voz (o Draenei não tem frases próprias), por exemplo "Estou mais forte do que estava hoje de manhã." | | |
| 3.4 | Terra nova | Entre numa zona nova ou em um lugar novo | Página de zona sem erro. (Sem frase própria do Draenei: texto geral) | | |
| 3.5 | Morrer | Morra uma vez (queda ou criatura) | Página de morte. Pode vir uma frase de **Paladino** falando da Luz | | |
| 3.6 | Marco | No **nível 10**, se chegar | Frase de marco, sem número: "Uma estação da minha vida se fecha. Não sou mais quem partiu." (ou outra do mesmo conjunto) | | |
| 3.7 | Meta cumprida | Cumpra qualquer meta nova, se houver | A página da meta **não** diz "(+10 pontos)" | | |
| 3.7b | Missão na voz do povo | Com um personagem de **raça antiga** (por exemplo o Tauren), na voz Da minha gente, complete 6 a 8 missões e leia as páginas | Cerca de metade das páginas de missão falam como o seu povo (por exemplo, "A Mãe Terra me viu terminar ... e foi paciente comigo"); as demais seguem o tom de antes. O Draenei não tem essas frases: nele tudo segue como antes | | |
| 3.8 | Trocar de voz | Volte a **Épico** e depois a **Da minha gente** | As páginas de nível antigas ganham e perdem o número ao trocar | | |
| 3.9 | **Lore** | Leia 5 frases de nível ou morte | Soam fiéis ao mundo do jogo? Anote as que destoam: ____ | | |

## 4. Índice e mapa da zona (3 min)

| # | Passo | Como fazer | Esperado | OK | Notas |
|---|---|---|---|:-:|---|
| 4.1 | Índice | Aba **Índice**, na zona inicial | Mapa da zona, regiões encontradas, missões "feitas / total" e criaturas mortas | | |
| 4.2 | Total de missões | Anote o total: ____ | Faz sentido (nem 0, nem absurdo) | | |

## 5. Metas novas, em português (3 min)

| # | Passo | Como fazer | Esperado | OK | Notas |
|---|---|---|---|:-:|---|
| 5.1 | Categoria Guerra | Aba **Feitos** → **Guerra** | 16 metas em 3 páginas (`1 de 3`); os cantos do livro viram as páginas | | |
| 5.2 | Metas de campo de batalha | Páginas 2 e 3 | "Primeiro Sangue no Campo" (10 pts), "Uma Vida de Estandartes" (25 pts), "O Livro do Senhor da Guerra" (50 pts); texto "Campos de batalha vencidos: 10." etc.; sem código solto | | |
| 5.3 | Silêncio | Ao entrar no jogo com o novo personagem | Nenhuma página nem aviso de meta aparece de repente | | |
| 5.4 | Contagem | Olhe o topo da aba | "N de M metas" e "X de Y pontos" sem erro | | |

## 6. Campo de batalha (precisa de **nível 10**; 30 a 45 min com a fila)

Pode ser feito depois, com este personagem ou com o principal.

| # | Passo | Como fazer | Esperado | OK | Notas |
|---|---|---|---|:-:|---|
| 6.1 | Ligar o probe | `/skald probe events` | "contando todos os eventos do cliente..." | | |
| 6.2 | Jogar uma partida | Fila na Garganta Brado Guerreiro (ou outro) e jogue até o fim | Em poucos segundos aparece **um** aviso "Campo de batalha" | | |
| 6.3 | A página | Abra o livro | Uma página com o nome do campo; vitória ("Vitória em...", "Tomamos...") ou derrota ("Derrota em...", "ficou com o outro lado...") conforme o resultado | | |
| 6.4 | Ícone novo | Olhe o ícone da página | Dois **estandartes cruzados** (vermelho e azul). Quadrado branco ou elmo = jogo não reiniciado | | |
| 6.5 | Rabisco | Pé do dia da página | Pode aparecer um estandarte vermelho fincado no chão (não é erro se não vier) | | |
| 6.6 | Só uma página | Fique no placar um tempo | **Uma** página por partida, sem duplicar | | |
| 6.7 | Meta | Se venceu: aba **Feitos** → **Guerra** | "Primeiro Sangue no Campo" cumprida, com página e aviso de pontos (a voz "Da minha gente" não mostra pontos) | | |
| 6.8 | Busca | Aba **Busca**, filtro **Batalhas** | A página de campo de batalha aparece; o clique abre a página | | |
| 6.9 | Probe | `/skald probe events list` | Nomes como `UPDATE_BATTLEFIELD_STATUS xN` e outros com PVP ou BATTLEFIELD. **Mande o print** | | |
| 6.10 | Desligar | `/skald probe events off` | "contagem de eventos parada" | | |

## 7. Busca, Bardo, Backup e Ajustes (nunca vistos no jogo; 30 min)

| # | Passo | Como fazer | Esperado | OK | Notas |
|---|---|---|---|:-:|---|
| 7.1 | Busca | Aba **Busca**, digite uma palavra de uma missão | Lista em cerca de um quarto de segundo, palavra pintada, mais novas primeiro | | |
| 7.2 | Sem acento e maiúsculas | Digite a mesma palavra em MAIÚSCULAS e sem acento | Acha igual | | |
| 7.3 | Filtros | Tipo (Tudo, Missões, Batalhas, Saques...), favoritas, até quando | A lista diminui; só uma lista suspensa aberta por vez | | |
| 7.4 | Clique | Clique numa linha | O livro abre a página certa | | |
| 7.5 | Bardo: tocar | Aba **Bardo**, clique numa música | Toca; o relógio conta; notinhas perto da lareira | | |
| 7.6 | Bardo: controles | Próxima, anterior, **Aleatório**, volume | Troca de música; o volume da música do jogo muda | | |
| 7.7 | Bardo: aviso | Feche o livro com música tocando | Aparece o aviso na tela com o nome da música; arraste e veja se lembra o lugar após `/reload` | | |
| 7.8 | Bardo: fim da música | Deixe uma acabar | A próxima começa sozinha | | |
| 7.9 | Bardo: mudas | Anote as que ficam em silêncio: ____ | (informativo) | | |
| 7.10 | Backup | `/skald backup` | Janela com o texto em partes; copie tudo | | |
| 7.11 | Mudar e restaurar | Escreva uma nota num dia; `/skald restore`, cole as partes, confirme | O diário volta ao do backup; a nota some | | |
| 7.12 | Desfazer | `/skald restore undo` | A nota volta | | |
| 7.13 | Ajustes | **Ajustes**: vire as três páginas pelos cantos (Estilo, Avisos, Opções) | Nada sobreposto ou cortado | | |
| 7.14 | Visual das abas e papel | Troque o visual (Couro, Fita, Latão, Pergaminho, Madeira entalhada) e o papel | Cada escolha muda e fica guardada | | |

## 8. Entrega (5 min)

| # | Passo | Como fazer | Esperado | OK | Notas |
|---|---|---|---|:-:|---|
| 8.1 | Relatório | `/skald report` e copie | É a referência do Anniversary para comparar com o Forever no dia 04 | | |
| 8.2 | Erros | Revise o chat | Nenhum erro em vermelho. Se houve, mande o texto inteiro | | |
| 8.3 | Frases estranhas | Reúna as que soaram esquisitas, nos três idiomas se possível | Prints. Entram na revisão de idioma | | |

---

## O que mandar de volta

| Item | De onde vem |
|---|---|
| Resultado dos `/dump` (2.4 e 2.5) | Fase 2 |
| Print da primeira página da Saga | 2.7 |
| Print de uma página de nível e outra de morte, na voz nova | 3.3 e 3.5 |
| As frases que destoaram da lore | 3.9 |
| Print da lista do probe | 6.9 |
| O texto do `/skald report` | 8.1 |
| Qualquer erro do chat, **completo** | em qualquer fase |

## O que não dá para testar no Anniversary (fica para o dia 04)

| Item | Por quê |
|---|---|
| Frases do Skyborne, por facção, e o nome interno da raça | A raça só existe no Forever |
| Valores escondidos pelo cliente em luta (chefe, loot) | O Anniversary não os esconde |
| Reputação pela API nova | Só existe no cliente Mainline |
| Eventos de acampamento e de Legacy | Só existem no Forever |
| Ícone de campo de batalha no Leitor web | O site só muda quando a branch for publicada |
