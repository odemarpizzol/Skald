# Roteiro de teste, Skald (antes da 0.37.1-beta)

Marque cada fase com **pronto** ou **falhou** (com print e o que você fez). Cada passo diz o que esperar.
Lembrete: a simulação dos testes não é o jogo; só vale o que for visto aqui.
Faça as fases A e B primeiro: são as mudanças novas desta versão. As fases C a G são as que ficaram pendentes da 0.37.0.

## Fase 0: instalar (5 min)
1. Feche o jogo por completo (saia até o Windows). Isso é obrigatório: os ícones de pets são texturas novas.
2. A pasta `Interface\AddOns\Skald` já está atualizada. Abra o jogo e entre com um personagem que tenha diário.
3. `/skald`. **Esperado:** o livro abre, sem erro no chat (se aparecer erro, mande o texto inteiro).

## Fase A: Pets e balão do Leitor (novos)
**A1. Página de Pets (use um caçador com pet)**
1. Aba **Pets**. **Esperado:** no topo o pet ao seu lado, com ícone da família, nome e nível; o modelo 3D do pet junto dos fatos; abaixo a lista de companheiros com o ícone da família em cada linha, o atual com o nome mais escuro.
2. Olhe todos os ícones que aparecerem. **Esperado:** nítidos, sem quadrado branco, sem corte. Anote os que encostam na borda direita (crocolisco, gato, raptor já eram suspeitos).
3. Personagem que não é caçador. **Esperado:** a aba Pets não aparece, ou aparece sem erro.

**A2. Balão no Leitor**
1. `/skald reader`, copie o texto, cole em https://odemarpizzol.github.io/Skald/reader/ e abra o livro.
2. Passe o mouse numa página de **missão** e numa de **item**. **Esperado:** balão com nome, nível, raridade, o que a missão pedia, quem deu e o lugar.
3. Clique. **Esperado:** abre a busca no Wowhead Classic numa aba nova.
4. A capa mostra raça e classe.
(O site do Leitor só reflete o balão depois que eu publicar; se o balão não aparecer, me avise antes de achar que é falha.)

## Fase B: correções de dados (novas). Use um personagem de TESTE
**B1. Limpar o diário**
1. Num personagem com pets, metas cumpridas e companheiros, anote o que tem nas abas Pets e Metas.
2. `/skald clear` e confirme. **Esperado:** o livro fica vazio; no **Índice** aparece "Nenhuma página escrita ainda. Saia e viva a sua aventura!" abaixo do título (se o texto não couber ou ficar torto, mande print).
3. Abra Pets e Metas. **Esperado:** nada do que havia antes (os pets e metas antigos não ficam). Metas já cumpridas no jogo podem voltar sozinhas, em silêncio, sem gerar página.
4. Jogue um pouco. **Esperado:** páginas novas aparecem normalmente.

**B2. Arquivar e restaurar** (só se você tiver um diário arquivado; senão pule)
1. Opções → seção de arquivo → **Restaurar**. **Esperado:** voltam as páginas **e** os pets, metas e companheiros daquele diário; o livro mostra as páginas certas na hora (sem ficar com as do diário anterior).
2. Uma zona já visitada **não** gera "primeira visita" de novo, mesmo com o jogo em outro idioma.

**B3. Nomes na exportação**
1. Com companheiros de grupo, `/skald export`, formato **Leitor**, nomes **ocultos**. **Esperado:** nenhum nome de jogador, inclusive os do tipo `Nome-Reino`, e a nota de uma página favorita que cite um companheiro também sai com "um companheiro".
2. Troque para **visíveis**. **Esperado:** os nomes e a nota inteira aparecem.

**B3b. Nota nova**
1. Escreva uma nota num dia (tinteiro). **Esperado:** aparece no livro na hora.

**B4. Combate**
1. Suba de nível ou mate algo no meio de uma luta. **Esperado:** a página é escrita normalmente, sem erro. (O README agora diz que o diário escreve também em combate.)

## Fase C: ofícios (da 0.37.0, ainda não vista)
1. Fabrique o mesmo item três vezes seguidas. **Esperado:** uma só página: "3 de ...".

## Fase D: chefes e reencontros
1. Masmorra: morra uma ou duas vezes e mate um chefe. **Esperado:** a página fala das quedas.
2. Grupo com alguém que já esteve com você há um dia ou mais. **Esperado:** página de "velha companhia".
3. Favorite uma página, saia da zona e volte depois de um dia. **Esperado:** aviso discreto de "lembrança" no alto, uma vez por semana por zona.

## Fase E: mapa
1. Abra o mapa de uma zona com páginas suas. **Esperado:** os marcadores do diário ficam **por baixo** dos do jogo, e dá para clicar numa missão do jogo mesmo com um marcador seu em cima.

## Fase F: idiomas (se puder)
1. Cliente em inglês ou francês. **Esperado:** textos nesse idioma, sem códigos soltos nas metas e no Leitor.

## Fase G: olhada geral (5 min)
1. Abra cada aba: Capa, Índice, Dias, Metas, Pets, Mapa, Estilo, Avisos, Opções. **Esperado:** nenhuma com erro ou em branco (fora o Índice vazio da fase B1).
2. `/reload` no meio do jogo. **Esperado:** nada some.

---
Ao terminar, me diga: o que passou, o que falhou (com print), e se quer publicar a **0.37.1-beta**.
Se aparecer erro em vermelho no jogo, copie o texto completo (ou use `/console scriptErrors 1` antes de repetir o passo).
