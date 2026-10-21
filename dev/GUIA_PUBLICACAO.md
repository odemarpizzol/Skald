# Guia de publicação: Skald e Skald Atlas (beta)

Duas pastas prontas, cada uma será um repositório Git e uma página no CurseForge:

- `skald-repo/` → Skald (o diário)
- `skald-atlas-repo/` → Skald Atlas (os marcadores no mapa; precisa do Skald)

Cada pasta já tem: os arquivos do addon, `README.md`, `CHANGELOG.md`, `LICENSE` (MIT, autor Oddynho), `.pkgmeta` e `.github/workflows/release.yml`.

> Sobre o Git: sim, vale criar um repositório para cada addon. O CurseForge empacota e publica direto do GitHub quando você cria uma "tag", então você não precisa montar o zip na mão. Git já está instalado neste computador (versão 2.52).

## 1. Antes de tudo (no jogo)
- Teste o Skald uma última vez: abrir o livro, virar páginas, escrever uma nota, pegar um item, mudar uma opção.
- Tire as capturas de tela: capa, índice, uma página de dia com nota, Opções, o mapa com os marcadores (Skald Atlas).

## 2. Contas e páginas (feito por você, no navegador)
1. **GitHub**: crie uma conta (se ainda não tem) e dois repositórios **vazios**, públicos: `skald` e `skald-atlas` (sem README, sem licença, o conteúdo já vem nas pastas).
2. **CurseForge** (authors.curseforge.com): crie dois projetos, "Skald" e "Skald Atlas", jogo World of Warcraft. Escolha a categoria Roleplay (ou outra que fizer sentido). Cole a descrição de `CURSEFORGE_DESCRIPTION.md` e suba as capturas. Anote o **número do projeto** de cada um.
   - Verifique se a versão do jogo "Forever" aparece na lista; se não aparecer, me diga o que o CurseForge oferece.
3. **Token do CurseForge**: em "API tokens" da sua conta, crie um token.

## 3. Colocar o número do projeto no addon
Me diga os dois números. Eu adiciono ao `.toc` de cada um a linha `## X-Curse-Project-ID: 123456` e atualizo as pastas.

## 4. Enviar para o GitHub (uma vez por pasta)
Abra um terminal dentro de `skald-repo` e rode, trocando SEU_USUARIO:

```bash
git init -b main
git add .
git commit -m "Skald 0.26.0-beta"
git remote add origin https://github.com/SEU_USUARIO/skald.git
git push -u origin main
```

Repita dentro de `skald-atlas-repo` com `skald-atlas.git`.

## 5. Ligar o GitHub ao CurseForge
No GitHub, em cada repositório: Settings → Secrets and variables → Actions → New repository secret. Nome `CF_API_KEY`, valor o token do CurseForge.

## 6. Publicar a beta
Dentro de cada pasta:

```bash
git tag v0.26.0-beta
git push origin v0.26.0-beta
```

Para o Skald Atlas use `v0.6.0-beta`. O GitHub empacota e envia ao CurseForge. A tag com `-beta` publica como **beta**; uma tag sem sufixo (por exemplo `v1.0.0`) publica como versão estável.

## 7. Depois
- Quando mexermos no addon de novo, eu reconstruo as pastas (`skald-repo` e `skald-atlas-repo`) com os arquivos novos; você só faz `git add . && git commit && git push` e uma nova tag.
- Skald Atlas depende do Skald: publique o Skald primeiro.

## Não verificado (confira)
- O `.pkgmeta` e o fluxo do GitHub Actions seguem o formato do empacotador do BigWigs, mas não foram executados aqui.
- Regras do CurseForge para addons do Forever e o nome exato da versão do jogo.
- Licenças: Skald e Skald Atlas em MIT; fontes Cinzel, EB Garamond e Caveat em SIL OFL (textos em `Fonts/`); créditos ao QuestDB e ao CMaNGOS no README.
