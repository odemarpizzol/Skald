# Avaliação e atualização do Skald Reader

Data: 08/11/2026. Base: addon 1.0.1 no workspace. O GitHub Pages não foi publicado. Os arquivos do addon foram sincronizados com a instalação Forever ao concluir a revisão da tela de exportação, conforme registrado abaixo.

## Resultado

O Reader estava atrás do livro atual em apresentação e em dados exportados. A revisão atualiza o visual com a arte do addon, preserva as preferências de leitura e a organização dos dias, corrige textos cortados e reforça a montagem das partes copiadas. Continua sendo um leitor do diário exportado, com capa, resumo, índice, Saga, favoritos e anotações.

| Diferença encontrada | Correção |
|---|---|
| Moldura de couro feita em CSS e papel antigo | Moldura, lombada, quatro papéis, cantos, pena e divisor convertidos das texturas atuais do addon para PNG. Proporções das folhas aproximadas às do livro do jogo. |
| Vários ícones PNG ainda usavam o desenho antigo | 137 PNGs sincronizados com os TGAs atuais: eventos, itens, profissões, selos, elementos do livro e ilustrações da Saga. Incluídos os ícones ausentes de munição, mão secundária, relíquia, tabardo, arma de arremesso e joalheria. |
| Papel, tinta, tamanho, densidade e título da capa não chegavam ao navegador | A exportação leva essas escolhas. O Reader valida os valores e aplica as opções suportadas. |
| Dias reconstruídos apenas pelo calendário local do navegador | A exportação leva as chaves, a numeração, a data e os títulos dos dias usados pelo addon. Duas sessões na mesma data permanecem separadas quando essa opção está ativa no jogo. |
| Entradas limitadas a 700 caracteres e anotações a 300 na exportação | O Reader recebe o texto completo. Blocos maiores que uma folha continuam nas seguintes, mantendo texto, Unicode e quebras de linha. |
| Saga paginada por uma estimativa de caracteres | A paginação mede os parágrafos com as fontes carregadas e divide capítulos longos. |
| Saga sem as ilustrações do addon | Artes dos oito capítulos, acampamento da facção, divisor, capitular com Cinzel Decorative e louros. A primeira folha do capítulo reserva espaço para sua ilustração; o epílogo recebe a cena final. Exportações novas levam a arte escolhida pelo addon. As antigas usam a chave do capítulo, com inferência de facção para as raças conhecidas e arte neutra quando a raça não é reconhecida. |
| Livro inteiro muito reduzido no celular | Uma folha por vez em telas estreitas, mantendo navegação e posição ao alternar para duas folhas. |
| Links de missões e itens sempre apontavam para Forever | Edição exportada pelo addon: Forever, TBC ou Classic. Exportações antigas conservam o padrão anterior, Forever. |
| Partes identificadas principalmente por nome e contagem | Validação compartilhada entre formulário e parser, detecção de partes conflitantes e identificação da exportação completa por checksum adicional. |
| Cópias para impressão repetiam IDs das páginas visíveis | IDs removidos dos clones, evitando ambiguidade após gerar o PDF. |

A soma de `level` e `milestone` no resumo foi preservada: no modelo atual, `milestone` também representa níveis especiais. Não era um erro do contador.

## Compatibilidade e uso

- Exportações antigas `SKALDREADER1` continuam abrindo, com as opções visuais padrão e o agrupamento antigo. A edição do cliente e as preferências ausentes não podem ser recuperadas dessas cópias.
- O cabeçalho mantém os campos anteriores nas mesmas posições. Novos registros opcionais e campos finais permitem que Readers antigos ignorem as informações extras.
- Para ver o papel, os títulos dos dias e as outras opções atuais, é necessário carregar o addon atualizado e copiar novamente com `/skald reader`.
- Os textos continuam sendo montados pelo addon no idioma e na voz escolhidos ao exportar. O Reader não recria frases nem troca a voz de uma cópia já exportada.
- A leitura continua local ao navegador. Não há envio do diário; links para Wowhead só abrem por ação do usuário.

## Validação

- `node dev/tools/checks.js`: **All checks passed**, incluindo sintaxe, regressões, sessões simuladas, frases, Reader e desempenho. Log da execução válida: `/tmp/skald-reader-review-verified.log`. A primeira tentativa foi invalidada pelo bloqueio de subprocessos com EPERM no sandbox.
- `node dev/tools/reader_test.js`: **37 checks aprovados**, incluindo os perfis Forever/TBC, preferências, notas longas, sessões na mesma data, cópias antigas, partes fora de ordem, duplicatas, conflitos, checksum global, contagem de entradas e seleção das artes da Saga.
- Chromium via `python3 dev/tools/reader_browser_test.py`: inglês, português e francês; quatro papéis; três tamanhos e densidades; celular e retorno ao desktop; impressão/PDF; capítulos, entradas e notas extensos. Comparação do texto completo confirmou ausência de perda ou duplicação nos blocos testados, e a geometria das folhas não mostrou conteúdo cortado.
- Teste de carga no navegador: 3.000 entradas abriram em aproximadamente **200 ms** neste ambiente, depois da colagem. É uma medida com dados artificiais e não uma garantia para qualquer dispositivo.
- As verificações de navegador não observaram solicitações externas, arquivos ausentes ou erros de JavaScript. Texto com aparência de HTML foi exibido literalmente, sem execução.

Para repetir os testes de navegador, instale Python Playwright/Chromium e inicie `node dev/tools/serve_docs.js 8765` antes de executar o script.

Para atualizar as artes sem redesenhá-las, execute `python3 dev/tools/sync_reader_art.py` (requer ffmpeg). A ferramenta converte os TGAs do addon, preserva dimensões e alfa e recorta a região útil do atlas da moldura. A conferência de navegador foi repetida depois da sincronização das artes e passou, sem arquivos ausentes.

Capturas e PDF estão em `output/reader-review/` (dados de teste, sem diário pessoal):

- `reader-cover.png`: capa e resumo.
- `reader-desktop.png`: páginas de diário em duas folhas.
- `reader-mobile.png`: uma folha em tela estreita.
- `reader-saga.png`: capítulos da Saga produzidos pelo addon a partir do diário de teste.
- `reader-saga-chapters.png`: abertura da Saga com as ilustrações e a capitular.
- `reader-long-text.png` e `reader-mobile-long-text.png`: casos extensos de paginação.
- `reader-print.pdf`: impressão do caso extenso.

## Diferenças que permanecem em relação ao jogo

O Reader ainda não tem o modelo 3D do personagem, as páginas interativas do Atlas/Cartógrafo, o catálogo completo de Feitos, o Bardo ou as configurações do addon. Esses recursos não estão contidos no formato exportado. Acrescentá-los exigiria ampliar os dados e a interface, além desta atualização do leitor.

O acabamento usa a mesma arte, mas a paginação web adapta fontes e conteúdo ao navegador; não é uma reprodução pixel a pixel do cliente. A revisão foi validada com exportações simuladas. Falta conferir uma nova cópia de um diário real depois do `/reload` e publicar os arquivos web para que a versão online receba as mudanças.

## Tela de exportação no jogo

A janela de exportação foi reorganizada no projeto: moldura de couro e papel do livro, cabeçalho menor, opções alinhadas, indicação da parte atual, resumo de páginas/partes e botão **Selecionar texto**. O botão coloca foco no campo e seleciona o conteúdo para Ctrl+C; ele não promete copiar automaticamente para a área de transferência.

Trocar de parte reutiliza a exportação já preparada. Mudar formato, escopo, nomes ou reabrir a janela recompõe os dados. Os controles anterior/próximo ficam desabilitados nos limites, e uma seleção vazia desabilita a cópia. O rodapé do Reader separa instrução, endereço e privacidade; nos outros formatos, o campo de texto ganha mais altura. A janela ajusta sua escala ao espaço disponível e acompanha o papel escolhido no livro.

As instruções novas estão em inglês, português e francês. A suíte completa terminou com **All checks passed** em `/tmp/skald-export-ui-verified.log`; depois do ajuste final das margens, os três testes específicos da janela e o lint passaram novamente. Os testes cobrem cópia/seleção, navegação sem recompor o diário, mudança de formato ao reabrir e seleção vazia.

`output/reader-review/export-dialog-preview.png` é uma **simulação visual do layout**, acompanhada do HTML da prévia. Não é uma captura do cliente. Os arquivos Skald.lua, Locales.lua, Saga.lua e Skald.toc foram aplicados em `/mnt/d/Games/World of Warcraft/_forever_/Interface/AddOns/Skald/` e comparados por SHA-256 com o projeto. Os demais módulos Lua já coincidiam. O TOC agora acompanha a versão 1.0.1 do projeto. Os arquivos anteriores estão em `/tmp/skald-export-before-2iim5uvv/`. Falta a conferência visual da janela pelo jogador após `/reload`; não foi necessário criar texturas novas para esta tela.

A captura enviada pelo jogador revelou o título encostando na faixa de couro. O cabeçalho foi deslocado 10 pontos para baixo e subtítulo/instruções passaram a usar SkaldSmall, a fonte do livro. Os testes da janela e o lint passaram; Skald.lua foi reaplicado no Forever e comparado com o projeto. Backup anterior a esse ajuste: `/tmp/skald-export-header-before-95g_oyqw/`. Falta conferir o recuo novo no cliente após `/reload`.
