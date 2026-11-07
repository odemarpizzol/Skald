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
