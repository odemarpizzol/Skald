# Avaliação do Skald para a versão 1.0

Avaliação de 07/11/2026 sobre `0.50.0-beta`, commit `8cf4ab3`. Revisão de código, ferramentas de publicação, documentação, recursos gráficos e verificações locais. Este relatório não certifica funcionamento no cliente do jogo. As capturas fornecidas demonstram telas reais, mas não comprovam todos os eventos e cenários de recuperação.

## Atualização após as correções solicitadas

O diagnóstico abaixo registra a situação original da auditoria. As seguintes correções foram aplicadas depois, mantendo a versão atual e sem criar tag ou publicar:

- `Backup.Undo` agora reinicializa o contexto de sessão e reverte as duas cópias se a atualização falhar.
- O diário avisa perto de 3.000 páginas e conserva todas elas até uma confirmação explícita. `/skald retention` permite revisar a escolha; escolher Manter páginas ou fechar a pergunta suspende a remoção futura. Favoritos e notas continuam protegidos após a aceitação.
- As novas páginas guardam a voz de origem. Ao trocar de voz, a leitura pode usar os pools da voz atual; voltar à original recupera o pool e índice originais. Páginas antigas inferem a origem dos pools de tom quando disponíveis. As histórias especiais de missões continuam dedicadas.
- O equalizador voltou a ter alpha visível nos três quadros. Os controles do Bardo agora usam o símbolo de Parar já existente no conjunto visual.
- O novo validador verifica cabeçalho, dimensões, profundidade, dados completos e alpha das 382 texturas. Ele também identificou quatro ícones HUD de 96×96, convertidos para 128×128 preservando transparência.
- Checks rejeitam erros de subprocesso, sinais e saída obrigatória ausente. Há testes específicos para o caso EPERM/status zero e para TGA transparente com rodapé não vazio.
- O workflow valida pushes em main/dev, pull requests e execuções manuais. O upload só é habilitado para push de tag de versão e depende dos checks.
- O guia e o README das ferramentas usam o fluxo atual de um único addon. O script antigo de release foi desativado antes de qualquer mutação ou upload.
- Um ZIP local de revisão foi montado a partir dos arquivos do addon e passou pela verificação de integridade e estrutura, com TOC, fontes/licenças e texturas. Ferramentas, documentos de trabalho, PDFs e ZIPs não entraram nele. Isso não substitui conferir o artefato gerado pelo serviço na publicação futura.

Continuam pendentes: a matriz dentro dos dois clientes reais, revisão editorial/nativa de francês, medições reais de primeira busca e gravação em diário grande e a validação do artefato efetivamente publicado. Esses pontos exigem evidência de jogo ou uma publicação autorizada; não são declarados concluídos pelos testes simulados.

**Validação final das correções:** `node dev/tools/checks.js` terminou com `All checks passed` e código zero, sobre os arquivos finais. Foram aprovadas 382 texturas, os 270 resultados de regressão, as sessões simuladas, os três idiomas, os testes das ferramentas e os dez checks do Reader. O benchmark simulado final registrou capa em 527 ms, página em cache em 3,3 ms, mapa em 68 ms, Saga em 10 ms, exportação em 691 ms e Reader em 1.494 ms. O teste de retenção inclui cancelamento, retomada da escolha e rejeição de uma confirmação antiga depois de substituir as páginas.

O pacote local está em `output/Skald-0.50.0-beta-review.zip`; o log completo está em `output/skald-1.0-checks.log`. O ZIP passou por `unzip -tq`, possui uma única raiz `Skald/` e teve os arquivos funcionais alterados comparados por SHA-256 com o workspace. É um pacote de revisão da versão atual, sem alteração de TOC, tag ou upload.

**Parecer: o Skald já tem conteúdo e identidade para uma 1.0. Recomendo entrar em estabilização, corrigir os pontos abaixo e validar uma candidata no jogo antes de marcar uma versão estável.** Não é necessário acrescentar funcionalidades para justificar o número 1.0.

## O que já está bem encaminhado

- O produto tem uma proposta clara: diário pessoal, narrativa, livro e coleção de memórias. Busca, Saga, Atlas, Cartógrafo, Bardo, metas e Reader complementam essa proposta.
- Há proteção dos registros pessoais: o limite de páginas preserva favoritos e notas. Contadores permanentes têm migração própria e não dependem apenas das páginas restantes.
- O backup usa um formato de dados próprio, sem executar Lua colado pelo usuário. Verifica partes, checksums, identidade do personagem e estrutura antes de aplicar. A restauração normal conserva uma cópia anterior e possui rollback em caso de erro.
- Existem testes de regressão de migração, personagens, retenção, exportação, restauração, filtros, eventos e vários erros anteriores. A execução direta de regressões terminou com 265 resultados `ok` e sem falhas.
- As frases e interfaces passam pela validação estrutural dos três idiomas. Os cenários de sessão simulada passaram em enUS, ptBR, frFR e nos perfis Forever disponíveis.
- A inicialização distribui manutenção entre timers, pausa essa manutenção em combate e possui instrumentação. Busca, layout e estatísticas usam caches.
- O Reader constrói o texto importado com `textContent`/nós de texto nos pontos revisados. Os dez checks próprios de importação, partes, escape e checksum passaram.
- A publicação por tag depende de um job de checks. A pasta `dev` é excluída do pacote, permitindo manter relatórios e ferramentas fora do addon instalado.

## Achados prioritários

P1 = resolver antes da 1.0 por integridade dos dados ou confiança do usuário. P2 = corrigir ou estabelecer um comportamento explícito antes da candidata final. P3 = melhoria posterior. Um ponto de validação pendente não significa que a função esteja quebrada.

| Prioridade | Achado e evidência | Consequência | Critério para encerrar |
| --- | --- | --- | --- |
| P1 | `Backup.Undo`, em `Backup.lua:425`, troca as tabelas e chama `RefreshDiary` sem a proteção existente em `Backup.Apply`. Também não chama `ReadAfresh`. Uma falha de refresh injetada reproduziu o erro depois de a troca já ter ocorrido. | O comando pode falhar deixando o diário trocado; dados de sessão restaurados podem ficar desatualizados. A cópia oposta continua disponível, portanto este achado não comprova perda definitiva. | Aplicar ao desfazer o mesmo cuidado transacional da restauração, revisar a reinicialização de sessão e cobrir falha durante o refresh, undo e redo. |
| P1 | `Skald.lua:356` remove os registros não pessoais mais antigos ao passar de 3.000. O aviso `OVER_CAP` só aparece quando os registros protegidos mantêm o total acima do limite. O README não informa claramente essa retenção. | Uma pessoa pode descobrir tarde que partes antigas de seu diário foram removidas deliberadamente. | Explicar o limite na interface e documentação e avisar antes da primeira remoção. Definir claramente a orientação de backup/exportação. Não é necessário prometer armazenamento ilimitado. |
| P1 — validação | O README ainda declara sem confirmação real vários eventos centrais: masmorras, chefes, grupos, montarias, conquistas e guilda; também há lacunas Forever/Skyborne/JxJ. Algumas dessas declarações podem apenas estar desatualizadas. | A promessa pública é maior que a evidência documentada. Mocks não confirmam payloads, APIs protegidas, som, renderização ou combate reais. | Registrar uma matriz de testes reais dos dois clientes anunciados; atualizar cada caso como confirmado, limitado ou fora do escopo. |
| P2 | `PoolFor`, em `Skald.lua:798`, prefere o pool persistido em `e.fl`. Reproduzi uma página `weather` com `tone_humor_weather`: selecionar humilde produziu o mesmo texto. A exceção dinâmica `KinPool` cobre níveis/marcos. | A promessa de que trocar a voz reescreve as páginas antigas não é verdadeira de forma geral. | Decidir entre voz dinâmica e voz histórica por página; alinhar código, interface e README. Testar uma página antiga em cada voz, incluindo retorno à voz anterior. |
| P2 | Os três arquivos `Textures/skald2/bard_eq_1..3.tga` possuem alpha zero em todos os 8.192 pixels de cada imagem. A leitura foi limitada ao bloco real de pixels do TGA, excluindo o rodapé. | O equalizador fica totalmente transparente. Este é um erro na alteração de arte feita nesta conversa. | Reexportar os três quadros com alpha válido e conferir sobre o papel do livro. Validar todos os quadros, não apenas a existência do arquivo. |
| P2 | `dev/tools/checks.js` avalia principalmente `status` de `spawnSync`, sem tratar `error` e validar a saída esperada. No sandbox observei `error=EPERM`, `status=0` e saída vazia: algumas etapas apareceram aprovadas com zero resultados, e performance falhou com `NaN`. A suíte foi reexecutada com permissão para subprocessos. | Uma limitação do executor pode produzir diagnósticos enganosos. O `NaN` inicial não mede lentidão do addon. | Falhar explicitamente se houver erro do subprocesso, sinal ou ausência de resultados obrigatórios; mostrar stderr e causa original. |
| P2 | A verificação de texturas procura nomes/arquivos. Ela não verificou o conteúdo alpha dos quadros acima. | Um recurso pode estar presente e ser invisível ou inválido visualmente, com a suíte verde. | Incluir validação de cabeçalho, tamanho, profundidade e presença de pixels visíveis para as imagens que deveriam conter arte. Manter revisão visual no jogo. |
| P2 | `dev/GUIA_PUBLICACAO.md` descreve dois addons e diretórios antigos; `dev/tools/release.js` ainda calcula caminhos do layout `Skald-publish`. O workflow atual utiliza outro caminho. | Uma pessoa seguindo o procedimento antigo pode preparar um pacote incorreto ou se confundir sobre o fluxo oficial. | Documentar um único procedimento vigente, testar o ZIP candidato e adaptar ou desativar explicitamente o script antigo. |
| P2 | O workflow em `.github/workflows/release.yml` executa checks no push de tags. | Problemas podem ser descobertos apenas quando a tag de publicação já foi criada. | Executar checks também em PR/push da branch de trabalho/publicação, mantendo o gate anterior ao upload. |
| P2 — experiência | O Bardo usa ícones de pausa em `Bard.lua:599` e `Bard.lua:612`, mas `Bard.Stop` chama `StopMusic`; o próprio README diz que não há pausa/seek. | O ícone sugere continuar do mesmo ponto, comportamento que a implementação não oferece. | Usar símbolo/tooltip de parar ou explicar diretamente o comportamento ao interagir. Confirmar som desligado, próxima/anterior, fim automático e volume global nos dois clientes. |

## Desempenho e tamanho

O repositório tem cerca de 65 MB de texturas e 382 arquivos TGA rastreados. Tamanho em disco não equivale à memória gráfica usada nem ao tempo para abrir uma página. Não recomendo comprimir/reduzir tudo antes de medir quais telas carregam quais recursos.

Execução direta de `node dev/tools/perf.js`, com 3.000 páginas em Fengari:

| Operação | Resultado observado |
| --- | ---: |
| Abrir capa | 520,2 ms |
| Atualizar página com layout em cache | 3,3 ms |
| Ir a página distante | 3,2 ms |
| Marcadores de um mapa | 61,9 ms |
| Primeira busca, com renderização dos textos | 655,0 ms |
| Busca repetida | 32,2 ms |
| Saga | 14,9 ms |
| Exportação com nomes ocultos | 775,9 ms |
| Texto para o Reader | 1.550,5 ms |
| Arquivo salvo simulado | 523 KB |

Esses tempos pertencem ao interpretador de teste e à máquina deste ambiente. Não são tempos de frame do WoW. A primeira busca síncrona e as exportações merecem medição real; o resultado isolado não justifica atribuir travamentos a elas. O benchmark também registrou `AddEntry` em 617,2 ms por operação no cenário repetido, que merece investigação com o diário e a janela reais antes de qualquer conclusão de performance.

A manutenção já cede entre tarefas, mas cada tarefa permanece atômica. Migrações e outras etapas anteriores à fila também precisam entrar na medição. Antes da 1.0, coletar `/skald perf` num login frio e num diário grande, incluindo primeira abertura do Índice/Cartógrafo, primeira busca, mapa, exportação e combate. Relacionar cada pico ao recurso que o provoca. Não exigir refatoração geral sem essa evidência.

## Matriz de aceitação proposta

Executar no Forever e no Anniversary anunciados. Usar um personagem novo e um diário atualizado de uma beta anterior; repetir os fluxos principais com um diário grande. Testar com e sem QuestDB. A cobertura estrutural dos três idiomas não substitui conferir cortes e textos longos nas telas.

| Área | Casos mínimos | Evidência de aprovação |
| --- | --- | --- |
| Entrada e continuidade | Login frio, reload, logout/login, troca de personagem, carregamento de zona, entrar/sair de combate durante manutenção | Sem erro Lua e sem perder/duplicar páginas; eventos continuam sendo registrados durante a manutenção |
| Diário | Entregar missão, subir nível junto à entrega, morte/ressurreição, loot, fabricação repetida, profissão, voo e lareira | Evento e quantidade corretos; horário/zona corretos; configurações de registro respeitadas |
| Conteúdo de grupo | Entrar em instância, concluir chefe, entrar/sair de grupo/guilda, resultado de campo de batalha | Uma página para o evento esperado, identidade correta e contadores coerentes |
| Dados e recuperação | Atualização de beta, backup em partes, restaurar, desfazer/refazer, cancelar, parte incompleta/alterada, personagem errado | Páginas, notas e favoritos preservados; recusa não altera nada; falha injetada não deixa troca parcial |
| Retenção | Aproximar-se de 3.000 páginas, cruzar o limite, muitos favoritos/notas | Usuário sabe o que será retido; registros protegidos continuam presentes; contadores não retrocedem |
| Livro | Todas as abas, textos longos, tamanho de fonte máximo, escala de UI e duas resoluções comuns | Sem sobreposição, corte dos controles ou área clicável deslocada; artes visíveis em todos os quadros |
| Mapas | Zona, cidade, masmorra, raide e JxJ; não visitado/visitado; trocar mapas e clicar em pin | Imagem e nome certos, cor de visita correta, navegação abre a página correta |
| Voz e idioma | As quatro vozes em páginas novas e antigas; inglês, português e francês | Comportamento condizente com a promessa da interface; sem tags ou placeholders aparentes |
| Bardo | Tocar/parar, próxima/anterior, aleatório, terminar faixa, livro fechado, música/som desligado, controle de volume | Música e indicador coerentes; movimento leve; volume global claramente explicado |
| Reader/exportação | Várias partes, nomes ocultos, notas, favoritos, Saga e impressão/PDF | Importação íntegra e legível; nomes permanecem ocultos quando escolhido; PDF utilizável |
| Pacote | Instalar o ZIP em pasta limpa, conferir TOC e dependências opcionais, atualizar uma instalação antiga | Uma pasta Skald válida; nenhum arquivo necessário ausente; nenhum material de trabalho incluído |

Guardar data, versão do addon, cliente/build, idioma, resultado e `/skald report` quando houver erro. Atualizar afirmações antigas de “nunca visto no jogo” com os testes e capturas que já existem, sem repetir testes desnecessariamente.

## Conteúdo, linguagem e apresentação

- A identidade do livro está consolidada. Os ajustes recentes de arte mostram que ainda vale uma revisão visual de todas as abas, inclusive estados inativos, vazios e animados.
- Os 276 textos completos relacionados ao clima são variantes localizadas, não 276 experiências diferentes em cada idioma. As complementações raciais/de classe usam modelos combinados com fragmentos; revisar o resultado final, especialmente repetição, gramática e comprimento das páginas.
- O validador verifica estrutura, tags e algumas regras de conteúdo. Ele não faz revisão editorial nativa de francês, e o README admite isso. Fazer uma revisão humana dos textos mais visíveis antes de anunciar francês como plenamente revisado.
- Confirmar o recorte de conteúdo do Cartógrafo por cliente. Compatibilidade com TBC não significa que toda instância TBC já tenha arte própria; documentar as ausências esperadas.
- O Reader e os exports são parte da experiência de guardar um diário. Tratar uma exportação sem cortes e um backup recuperável como critérios de aceitação da 1.0.

## Caminho recomendado para lançar

1. **Estabilização:** congelar funcionalidades da 1.0 e registrar o escopo: Forever e Anniversary, três idiomas, integrações opcionais. Resolver integridade de undo, política de retenção e comportamento de voz. Corrigir o alpha do equalizador e a indicação de parar/pausar.
2. **Ferramentas e pacote:** robustecer os checks, adicionar validação de recursos, revisar o procedimento oficial e preparar o ZIP candidato. Confirmar todos os checks com saída completa e a instalação limpa.
3. **Candidata de lançamento:** escolher uma versão candidata, completar a matriz real com sessões normais de jogo e registrar problemas por gravidade. Repetir somente os fluxos afetados por cada correção e os checks gerais exigidos pelo projeto.
4. **1.0.0:** publicar quando não houver problema conhecido de perda/duplicação ou recuperação inconsistente, os fluxos centrais estiverem confirmados nos clientes anunciados, as limitações estiverem escritas e o pacote candidato for o mesmo que foi aprovado.

Não há necessidade de implementar retail, hardcore, transmog, voz sintetizada, crônica compartilhada ou uma reescrita de arquitetura para lançar esta 1.0. O arquivo principal com cerca de 9.000 linhas e `Locales.lua` com cerca de 10.000 merecem modularização futura, mas mover muito código durante a estabilização amplia a área a revalidar.

## Verificações desta avaliação

- Sintaxe dos arquivos carregados e análise estática com parser configurado para Lua 5.1.
- Validação de frases em enUS, ptBR e frFR: sem problemas reportados.
- Sessões simuladas nos três idiomas e nos perfis Forever oferecidos pela suíte.
- Execução direta de regressões: 265 resultados `ok`, sem falhas.
- Reader: dez checks aprovados.
- Benchmark direto com 3.000 páginas: números registrados acima.
- Reproduções isoladas, fora dos testes versionados, confirmaram voz antiga persistente e undo sem rollback em falha de refresh.
- Inspeção binária do alpha dos quadros do equalizador confirmou zero pixels visíveis.
- A primeira execução agregada foi invalidada pelo bloqueio de subprocessos do sandbox (EPERM). O `NaN` resultante não foi tratado como medida de desempenho. A reexecução completa com permissão adequada terminou com `All checks passed` e exit code 0: capa 510 ms, página 3,1 ms, mapa 62 ms, Saga 11 ms, exportação 748 ms e Reader 1.495 ms no benchmark simulado.

A auditoria original não alterou código funcional. As correções subsequentes estão descritas na atualização no início deste arquivo. A versão, as tags e a publicação permanecem sem alteração nesta rodada.
