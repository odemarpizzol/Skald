# Publicação do Skald

Este repositório contém um único addon, Skald. Atlas faz parte dele. O fluxo oficial é `.github/workflows/release.yml`, com BigWigs Packager e projeto CurseForge `1748824`. O antigo `dev/tools/release.js` está desativado e não altera arquivos nem faz upload.

## Preparar uma candidata

1. Escolher a versão com o responsável pelo projeto. Avaliações e correções não autorizam publicação automaticamente.
2. Rodar `npm ci --prefix dev/tools` quando as dependências precisarem ser instaladas e `node dev/tools/checks.js` na raiz do repositório. O processo precisa terminar com `All checks passed` e código zero. Erro ao iniciar subprocesso também é falha.
3. Completar os casos relevantes da matriz em `dev/AVALIACAO_1_0.md` nos clientes anunciados. Os testes automatizados simulam APIs; não confirmam o comportamento no jogo.
4. Preparar `Skald.toc` e `CHANGELOG.md` com a mesma versão escolhida. Usar `dev/NEXT_CHANGELOG.md` como notas de trabalho e consolidar as mudanças no changelog da versão.
5. Conferir os arquivos do commit e a revisão: não adicionar PDFs, ZIPs de trabalho, capturas privadas nem credenciais. O pacote deve conter uma única pasta `Skald/`, o TOC, os Lua carregados, `icon.tga`, `Textures/`, `Fonts/` e as licenças necessárias.
6. Testar a instalação do ZIP candidato numa pasta limpa e a atualização de um diário anterior. Preservar os SavedVariables e manter um backup antes de testar restauração. Texturas novas exigem reinício completo do cliente.

## Checks e publicação

Push nas branches `main`/`dev` e pull requests executam os checks. A execução manual também só valida. O job de upload roda exclusivamente em push de tag iniciada por `v`, depois de os checks passarem.

Somente depois da autorização de publicar, com o commit aprovado e a versão correspondente no TOC/changelog:

```bash
git tag vVERSAO_ESCOLHIDA
git push origin vVERSAO_ESCOLHIDA
```

Substituir `VERSAO_ESCOLHIDA` pelo número aprovado. Uma tag com `-beta` ou `-alpha` mantém a classificação correspondente; uma tag como `v1.0.0` indica uma versão estável. Não publicar uma candidata de testes como estável por engano.

O workflow usa `CF_API_KEY` dos secrets do GitHub e o token do próprio workflow. Tokens não devem aparecer em comandos, arquivos ou logs. `.pkgmeta` exclui ferramentas, documentação e arquivos internos do pacote.

## Confirmar a entrega

- Conferir os jobs `checks` e `release` na execução da tag.
- Baixar o artefato efetivamente publicado e conferir estrutura, versão do TOC e arquivos necessários.
- Confirmar na página de distribuição a versão, a classificação e os clientes anunciados.
- Registrar o resultado dos testes reais e atualizar as limitações do README. Só remover um aviso de validação pendente quando houver evidência do caso.

Não há um segundo repositório de Atlas nem uma cópia intermediária `skald-repo` neste procedimento.
