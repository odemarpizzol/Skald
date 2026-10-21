# Roteiro de teste, Skald (antes da 0.37.0-beta)

Marque cada fase com **pronto** (tudo bem) ou **falhou** (e mande print + o que você fez). Cada passo diz o que esperar.
Lembrete: a simulação dos testes não é o jogo, então o que está aqui só vale depois de visto aqui.

## Fase 0: instalar (5 min)
1. Feche o jogo por completo (saia até o Windows).
2. Apague a pasta `Interface\AddOns\Skald` e extraia `Skald-teste.zip` em `Interface\AddOns` (ou use a pasta que já está atualizada neste computador).
3. Abra o jogo, entre com um personagem que tenha diário.
4. Digite `/skald`. **Esperado:** o livro abre, sem erro no chat.

## Fase 1: o livro e a tela (5 min)
1. Aba **Estilo**, página da esquerda, embaixo: "Tamanho do livro" com Auto, 80%, 100%, 125%, 150%. Clique em cada um. **Esperado:** o livro muda de tamanho na hora, o botão escolhido fica aceso, e o livro nunca passa da tela.
2. `/skald size 80`, depois `/skald size auto`. **Esperado:** mesma coisa, com uma mensagem de confirmação.
3. Opções do jogo → Vídeo → escala da interface: ponha um valor alto, depois um baixo, com o livro aberto. **Esperado:** o livro se ajusta sozinho; as abas da esquerda continuam inteiras.
4. (Se puder) coloque o jogo em janela 1024×768 e abra o livro. **Esperado:** cabe inteiro.

## Fase 2: a capa e o espírito (5 min)
1. Capa com o personagem **vivo**. **Esperado:** o modelo 3D aparece, sem mancha branca depois de uns 5 segundos.
2. Morra e fique como **espírito**; abra o livro na capa. **Esperado:** no arco aparece uma imagem (vela na voz épica, espírito sorridente na humilde, lápide "R.I.P." na humorística). Mude a voz em Estilo para ver as três.
3. Volte ao corpo. **Esperado:** o modelo 3D volta.

## Fase 3: avisos e cartão (5 min)
1. Estilo → "Mover os avisos" mostra um aviso de exemplo. **Esperado:** selo, título e linha dourada alinhados; a linha dourada começa na mesma coluna do texto.
2. Arraste o aviso para o alto da tela e solte. `/skald resume`. **Esperado:** o cartão "Onde eu parei?" aparece **inteiro**, sem passar do alto da tela.

## Fase 4: aba Metas (10 min)
1. Aba **Metas**. **Esperado:** grupos à esquerda (A Estrada, Histórias, Companhia; Feras só para caçador), cada um com contagem e barra preenchida na proporção.
2. Clique em cada grupo. **Esperado:** as metas aparecem à direita, com ícone, nome, descrição e barra.
3. Numa meta **cumprida**, leia a linha de baixo. **Esperado:** diz o que a cumpriu (a missão da cadeia, o chefe, o companheiro) em vez de só "antes do diário contar". Passe o mouse e clique. **Esperado:** balão com o texto e a dica; o clique abre a página no livro.
4. As metas escondidas aparecem como "???" com o pergaminho lacrado.

## Fase 5: descrição da missão (5 min)
1. Aceite uma missão nova (de raridade incomum para cima) e entregue.
2. Passe o mouse na página dela no livro. **Esperado:** o balão mostra a descrição **em português**, e não em inglês.

## Fase 6: ofícios (5 min)
1. Fabrique o mesmo item três vezes seguidas. **Esperado:** uma só página, dizendo quantos ("3 de ...").

## Fase 7: frases (10 min)
1. Estilo → troque a voz entre épica, humilde e humorística e jogue um pouco (suba de nível, morra, entre numa zona nova).
2. **Esperado:** sem frase repetida em sequência; frases de classe e raça aparecendo; com personagem feminina, as formas femininas ("pronta", "tombada", "a mesma").

## Fase 8: chefes (se der, 15 min)
1. Entre numa masmorra, morra uma ou duas vezes e mate um chefe. **Esperado:** a página do chefe fala das quedas ("depois de duas quedas...").
2. (Opcional) `/skald probe`, repita, depois `/reload`, e me diga se apareceu algo de "ENCOUNTER_START".

## Fase 9: reencontros e lembranças (quando acontecer)
1. Grupo com alguém que já esteve com você numa masmorra, depois de um dia ou mais. **Esperado:** uma página "velha companhia".
2. Favorite uma página (estrela), saia da zona e volte depois de um dia. **Esperado:** um aviso discreto "lembrança" no alto, uma vez por semana por zona.

## Fase 10: o Leitor (10 min)
1. `/skald reader`. **Esperado:** a janela de exportação abre no formato **Leitor**, com: faixa de pergaminho no topo (livro e pena), ícone no botão "Leitor", prancheta no pé à esquerda da dica, selo verde no pé à direita.
2. Clique em "Discord" e de novo em "Leitor". **Esperado:** o cabeçalho some e volta.
3. Clique no texto, `Ctrl+A`, `Ctrl+C`; se houver partes (‹ ›), copie uma por vez.
4. Abra https://odemarpizzol.github.io/Skald/reader/ no navegador, cole. **Esperado:** "✓ Parte 1 de N", botão "Abrir o livro".
5. Abra o livro. **Esperado:** capa, "A história até aqui", índice, dias; setas e teclado; "Salvar como PDF".

## Fase 11: exportação (3 min)
1. `/skald export`: em "Discord" e "Texto simples" há o botão "Nomes de jogadores: ocultos/visíveis". **Esperado:** alterna e o texto muda (nomes viram "um companheiro").

## Fase 12: mapa (5 min)
1. Abra o mapa de uma zona com páginas suas. **Esperado:** os marcadores do diário aparecem **por baixo** dos do jogo; dá para clicar numa missão do jogo mesmo com um marcador seu em cima.

## Fase 13: idiomas (opcional)
1. Se puder, entre com o cliente em inglês ou francês. **Esperado:** textos nesse idioma, sem códigos soltos nas linhas de metas e no Leitor.

---
Ao terminar, me diga: o que passou, o que falhou (com print), e se quer publicar a **0.37.0-beta**.
