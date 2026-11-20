# Ferramentas do Skald

Executar a partir da raiz do repositório:

```bash
npm ci --prefix dev/tools
node dev/tools/checks.js
```

A suíte verifica sintaxe, lint Lua 5.1, formato/dimensões/alpha das texturas, frases nos três idiomas, sessões simuladas, regressões, Reader e desempenho com 3.000 páginas. Todo subprocesso precisa iniciar, terminar com código zero e produzir o resultado esperado. Uma execução verde é evidência da simulação, e não validação do jogo.

Comandos específicos:

```bash
node dev/tools/regressions.js
node dev/tools/validate_phrases.js
node dev/tools/reader_test.js
node dev/tools/perf.js
node dev/tools/tooling_test.js
node dev/tools/lint.js
```

As regressões incluem cenários de dados, eventos, interface e recuperação. Bugs novos devem receber cenários que reproduzam o comportamento, incluindo recusa/cancelamento e falhas durante operações destrutivas quando aplicável.

O procedimento oficial de release está em `dev/GUIA_PUBLICACAO.md`. O workflow executa checks em branches/PRs e só publica em push de tag de versão. `release.js` é um aviso de desativação do fluxo antigo; não deve ser usado para preparar ou enviar pacotes.

Verificação gramatical de todas as línguas (fora do `checks.js`, precisa do LanguageTool local; nada sai da máquina):

```bash
docker run -d --name skald-lt -e Java_Xmx=4g -p 127.0.0.1:8010:8010 erikvl87/languagetool
node dev/tools/lang_check.js deDE      # enUS, ptBR, frFR, esES, deDE; relatório em output/lang-check/<locale>.md; --picky para o modo mais rigoroso
docker stop skald-lt                    # docker start skald-lt na próxima vez
```

Uma língua por vez (as cinco juntas esgotam a memória do servidor). Cada frase é montada como o livro a mostra: lugares de cada tipo (plural, masculino, ilha, nome com artigo) via `ns.PlaceArticles`, `{g:...}` nas duas formas, a Saga para um e para muitos. Nomes do jogo que o corretor não conhece e achados já revisados (`!REGRA id`) ficam em `lang_check/<locale>.txt`. É um corretor, não um falante nativo nem o jogo.
