# Crônica da Guilda: prompts prontos para colar no Codex (arte e protótipo local)

Dois prompts independentes. Rode o **A (arte)** primeiro ou em paralelo; o **B (protótipo)** funciona sem a arte (usa um quadro vazio até os TGAs existirem, nunca uma imagem inventada). Contexto do plano: `dev/CRONICA_DA_GUILDA.md` (etapa G2).

Anexe ao A: `output/map-art/contact-sheet.jpg`, `Textures/skald2/map_corner.tga`, `map_compass.tga`, `rule.tga`, `Textures/ev_guild.tga`, `Textures/ev_party.tga`, `Textures/ev_boss.tga` e `Textures/pt_title*.tga`.

---

## A. Arte (só entrega PNG e TGA)

**O Codex só entrega a arte e os TGAs** em `Textures/skald2/`. Não mexe em `.lua` nem em testes.

```
Continue o trabalho de arte do Skald (addon de World of Warcraft, um diário épico em forma de livro de couro). Faça QUATRO peças para a nova aba "Crônica da Guilda", um livro coletivo onde os membros de uma guilda guardam aventuras vividas juntos (por exemplo, uma expedição às Minas Mortas). Mesmo estilo da arte já existente (veja os anexos): tinta marrom escura com hachuras finas, lavados de aquarela leves, ouro velho em pequenos detalhes, luz do alto à esquerda, SEM nenhuma letra ou número, fundo transparente, cerca de 8% de folga em cada lado (nada encostando na borda). Mesma paleta dos emblemas das Metas (pt_title*) e dos ornamentos (map_corner, rule).

1. BRASÃO DO LIVRO (guild_crest): um escudo heráldico simples e neutro (serve a qualquer guilda), cortado ao meio, com uma pena de escrever cruzada com uma espada curta atrás, em tinta e ouro velho, com uma fita enrolada embaixo (SEM texto na fita). Vai no cabeçalho do capítulo e na capa da seção.
   Formato: PNG com alfa, 256 x 256 px, desenho ocupando no máximo 86% da área.

2. DIVISOR DE CAPÍTULO (guild_divider): um filete horizontal ornamental para separar o texto do capítulo das lembranças dos autores: linha fina de tinta com um pequeno nó de folhas e ouro no centro, terminações afiladas, como o rule.tga porém mais elaborado.
   Formato: PNG com alfa, 512 x 32 px, o desenho ocupando 92% da largura.

3. SELO DE AUTOR (guild_quill): um pequeno selo redondo de cera vinho (#6E1F1A) com uma pena de escrever impressa em relevo, que marca cada lembrança assinada por um jogador. Deve ficar legível reduzido a uns 24 px.
   Formato: PNG com alfa, 64 x 64 px.

4. MARCAS DE ESTADO (guild_state): uma tira com TRÊS pequenos ícones lado a lado, de 32 x 32 px cada, para dizer o que aconteceu com uma contribuição: (a) "guardada só para mim": um pergaminho enrolado com um fecho de couro; (b) "aguardando envio": uma ampulheta de areia dourada; (c) "recebida de outro jogador": uma carta aberta com um selo de cera. Tinta e ouro velho, legíveis a 20 px, sem texto.
   Formato: PNG com alfa, 128 x 32 px (três ícones de 32 x 32, mais um quarto espaço vazio à direita para uso futuro).

Entrega:
- PNGs em output/guild-art/ (mande também versões 4x maiores para conferir).
- Converta cada um em TGA 32 bits SEM compressão (tipo 2), no tamanho em px acima (todas as dimensões são potências de 2, inclusive 512 x 32 e 128 x 32: confira), em Textures/skald2/guild_crest.tga, guild_divider.tga, guild_quill.tga e guild_state.tga. NÃO deixe PNG dentro de Textures/.
- Rode node dev/tools/checks.js e me diga o resultado (ele só confere se os TGAs citados no código existem; como eu ainda não liguei nada, deve passar sem mudança).
- NÃO altere nenhum arquivo .lua nem dev/tools.
```

---

## B. Protótipo local (G2): a aba, com dados de mentira, sem rede

```
Trabalhe no repositório Skald (addon de WoW Classic, Lua 5.1 do cliente). Leia primeiro CLAUDE.md, dev/CRONICA_DA_GUILDA.md, Chronicle.lua e Cartographer.lua (o modelo de uma aba nova: copie o padrão AddTab) e Pvp.lua (o modo "demo": desenha números de exemplo feitos no arquivo e não escritos em lugar nenhum).

OBJETIVO: uma aba "Crônica da Guilda" (arquivo novo ChronicleTab.lua, listado em Skald.toc depois de Chronicle.lua e Cartographer.lua) que mostre, SEM NENHUMA COMUNICAÇÃO, como será a experiência. É só para o usuário ver e dizer "é isso" ou "mude aquilo".

O que a aba mostra, só com o comando /skald chronicle demo (e /skald chronicle off para esconder; sem o demo a aba não aparece):
1. Um capítulo fictício: "Nossa expedição às Minas Mortas", data, instância, brasão (Textures/skald2/guild_crest.tga se existir; se não existir, um quadro vazio com a borda do livro, NUNCA uma imagem inventada), lista de chefes vencidos e a síntese. Monte o capítulo chamando Chronicle.Add e Chronicle.Chapters com um store de mentira criado na hora (em memória, jamais em SkaldDB nem SkaldCharDB), com duas contribuições de autores diferentes sobre a mesma aventura, para provar que os chefes se unem sem somar.
2. Duas lembranças assinadas, visualmente distintas do texto do capítulo (selo de autor guild_quill.tga, nome do autor, nota), separadas por guild_divider.tga (mesma regra do brasão: se o arquivo não existir, só uma linha de tinta desenhada pelo código).
3. A PRÉVIA que o jogador veria antes de compartilhar: título sugerido, fatos que serão enviados, nomes que aparecerão, campo de nota (EditBox com o limite Chronicle.MAX_NOTE e Chronicle.CleanText) e três botões: "Compartilhar", "Guardar para mim", "Dispensar". Os botões NÃO enviam nada: só trocam o estado mostrado (marca de guild_state.tga se existir) e escrevem uma linha dizendo "demonstração: nada foi enviado".
4. A opção "Não receber sugestões nesta guilda" como caixa de marcar, também só de demonstração.

REGRAS:
- NÃO chame Comms, SendAddonMessage, nem K.CommsRegister. NÃO grave nada em SkaldDB/SkaldCharDB, a não ser o interruptor da aba (SkaldDB.chronicleTab, como Pvp faz com pvpTab).
- NÃO altere Chronicle.lua nem Comms.lua; se achar um defeito, descreva no relatório.
- Textos novos nos QUATRO blocos de idioma (en/pt/fr/es) de Locales.lua; esMX aponta para esES. O francês usa NBSP antes de : ; ? ! e dentro de «». Português com acentos completos.
- Respeite o modo escuro: use ns.ThemeText/Tint/Fill/Alpha/Backdrop/Watch como as outras abas.
- TAB_RANK 4.4 (depois de pvp 4.3, antes da saga 4.5); registre o id "chronicle" e o nome da aba nos idiomas como as outras abas fazem (veja Cartographer e Pvp). Confira LayoutTabs com muitas abas.
- Tipos de letra e cores iguais às abas existentes; nada de widget novo com template que o cliente Forever possa não ter (use os templates simples que Pvp.lua usa).
- Limite de 200 locals no chunk: ponha constantes em uma tabela.
- Sem pedir nada ao usuário no meio: se uma decisão de visual ficar em aberto, escolha a mais simples e liste no relatório.

TESTES:
- Adicione um cenário em dev/tools/regressions.js que: monta o store de mentira, confere que o capítulo une os chefes sem somar, que /skald chronicle demo cria a aba e que NENHUM send de addon foi chamado e nada foi escrito em SkaldDB além do interruptor.
- Rode node dev/tools/lint.js, node dev/tools/regressions.js e depois node dev/tools/checks.js. Relate o resultado real, incluindo falhas.
- A simulação não é o jogo: diga isso no relatório e liste o que só dá para ver dentro do jogo.

NÃO faça commit nem publique. Entregue: arquivos alterados, comandos, saída dos testes e a lista de decisões de visual tomadas.
```

## Depois que o Codex terminar (eu faço)

- Revisar o que o Codex entregou (diff, regressões, que nada vaza para `SkaldDB`) antes de copiar para o jogo.
- Você vê a aba no jogo com `/skald chronicle demo` e decide o que mudar.
- Só então escolhemos onde guardar (conta ou personagem) e ligamos `Comms` (etapa G3).
