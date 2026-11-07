# Roteiro de teste para a 1.0

Marque cada linha: **OK**, **FALHOU** (anote o que viu e mande `/skald report` + print) ou **CORTAR** (não funciona, tira da 1.0). Cliente: ______ build: ______ idioma: ______ data: ______

Antes de começar: feche o jogo por completo e abra de novo (texturas novas). Rode `/skald report` uma vez e guarde o resultado.

## Sessão 1: diário antigo e arranque (5 min)
| # | Passo | Esperado | Resultado |
|---|---|---|---|
| 1.1 | Entrar com a Aelyndra (diário antigo) | Sem erro Lua; páginas antigas presentes | |
| 1.2 | `/reload`, depois logout e login | Nada duplicado nem perdido | |
| 1.3 | Abrir o livro, passar por todas as abas | Nenhuma aba com erro ou corte de texto | |
| 1.4 | `/skald perf` | Anotar os tempos (abrir livro, 1º segundo após login) | |
| 1.5 | Trocar a voz (4 vozes) | Páginas antigas mudam de texto; voltar à anterior devolve o texto de antes | |
| 1.6 | Trocar o idioma do jogo (pt, en, fr) | Textos e rótulos certos, sem `{tag}` aparente | |

## Sessão 2: personagem novo (20 min)
| # | Passo | Esperado | Resultado |
|---|---|---|---|
| 2.1 | Criar personagem, primeiro login | Página de início da raça; sem erro | |
| 2.2 | Entregar uma missão | Uma página de missão | |
| 2.3 | Subir de nível ao entregar | Página de nível, na ordem certa | |
| 2.4 | Entrar numa zona nova | Página de zona + mapa no Índice | |
| 2.5 | Morrer e ressuscitar | Páginas de morte e volta | |
| 2.6 | Pegar um item raro/verde | Página de item | |
| 2.7 | Aprender profissão, fabricar o mesmo item várias vezes | Uma página só, com contagem | |
| 2.8 | Voo (taxi) e pedra de regresso | Páginas de voo / lareira | |
| 2.9 | Nota própria num dia (tinteiro) | Vira página datada | |
| 2.10 | Favoritar uma página (estrela) | Fica marcada | |

## Sessão 3: grupo e mundo (30 min)
| # | Passo | Esperado | Resultado |
|---|---|---|---|
| 3.1 | Entrar numa masmorra | Página de masmorra; mapa da instância no Índice | |
| 3.2 | Matar um chefe | Página de chefe (uma só) | |
| 3.3 | Entrar e sair de grupo; entrar em guilda | Páginas/companheiros certos | |
| 3.4 | Campo de batalha: jogar e terminar | Página de vitória/derrota; contador na aba JxJ | |
| 3.5 | Aprender uma montaria | Página de montaria | |
| 3.6 | Conquista | Página de conquista | |
| 3.7 | Chuva/neve/areia forte por alguns minutos | Uma página de clima (no máximo uma a cada 45 min) | |
| 3.8 | Evento em combate (nível/morte no fim de luta) | Página escrita, sem erro | |
| 3.9 | Alcançar o nível 70 (Anniversary) | Meta e página do nível máximo | |
| 3.10 | Skyborne (Forever): zona, nível, morte | Frases próprias da raça | |

## Sessão 4: abas (20 min)
| # | Passo | Esperado | Resultado |
|---|---|---|---|
| 4.1 | Cartógrafo: 3 grupos de instâncias | Mapas coloridos nos visitados, esmaecidos nos outros; layout sem sobra estranha | |
| 4.2 | Índice dentro de uma instância | Mapa da instância, sem linhas de zona | |
| 4.3 | Busca: palavra de missão, lugar e nota | Resultados; clique abre a página | |
| 4.4 | Metas: ver pontos e título | Lista clicável | |
| 4.5 | Saga | Capítulos em primeira pessoa, sem erro | |
| 4.6 | Atlas (mapa-múndi): pinos | Aparecem; clique abre a página | |
| 4.7 | Bardo: tocar, parar, próxima, aleatório | Música toca; botão mostra Parar; notas sobem perto da lareira | |
| 4.8 | Bardo com livro fechado | Aviso na tela com o nome da faixa | |
| 4.9 | Aba JxJ | Aparece depois de um campo de batalha | |

## Sessão 5: dados e segurança (20 min)
| # | Passo | Esperado | Resultado |
|---|---|---|---|
| 5.1 | `/skald backup` | Texto em partes | |
| 5.2 | `/skald restore` com as partes, fora de ordem | Diário igual ao original | |
| 5.3 | Restaurar com uma parte faltando/alterada | Recusa, nada muda | |
| 5.4 | `/skald restore undo` | Volta ao diário anterior | |
| 5.5 | Restaurar em outro personagem | Recusa | |
| 5.6 | `/skald reader`, colar no Reader online | Diário legível; PDF utilizável | |
| 5.7 | `/skald export` com nomes ocultos | Nomes de outros jogadores ocultos | |
| 5.8 | `/skald retention` | Pop-up; "Manter páginas" não remove nada | |

## Sessão 6: pacote (10 min)
| # | Passo | Esperado | Resultado |
|---|---|---|---|
| 6.1 | Baixar o ZIP do CurseForge, instalar em pasta limpa | Uma pasta `Skald` só; sem `dev`, sem PDF | |
| 6.2 | Entrar no jogo com ele | Sem erro; fontes e texturas carregam | |
| 6.3 | Com e sem QuestDB | Funciona nos dois casos | |

## Critério para lançar a 1.0
Nenhum FALHOU que perca ou duplique páginas, nenhum erro Lua em uso normal, e todo item CORTAR fora do README e do CurseForge.
