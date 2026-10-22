# Skald: handoff para o Claude Code (2026-10-22)

Addon de World of Warcraft "Forever" (beta, `## Interface: 16001`), diário épico em primeira pessoa mostrado como um livro de couro aberto.
Autor Oddynho, MIT, CurseForge ID 1748824. Respostas ao usuário SEMPRE em português (pt-br).

## Onde está tudo
- Espaço oficial: `/home/odemarpizzol/work/dpzl/projects/Skald/Skald` (a pasta deve se chamar `Skald`; as ferramentas resolvem o addon como `<pai do repo>/Skald`). Branch `dev` = trabalho; `main` = publicação.
- O jogo lê de `D:\Games\World of Warcraft\_forever_\Interface\AddOns\Skald` (= `/mnt/d/Games/World of Warcraft/_forever_/Interface/AddOns/Skald`), pasta separada de `_classic_beta_`. Copie para as DUAS pastas (cp + cmp). `/reload` basta, exceto arquivo novo no `.toc` ou textura nova (reiniciar o jogo).
- Repo: https://github.com/odemarpizzol/Skald. Leitor web: https://odemarpizzol.github.io/Skald/reader/ (GitHub Pages serve `docs/` da `main`).
- Plano grande do usuário: `refactored-discovering-aurora.md` (Saga, crônica compartilhada, TTS, memórias do tempo).
- Memória do Claude: `~/.claude-personal/projects/-home-odemarpizzol-work-dpzl-projects-Skald-Skald/memory/` (regra `prefer-game-statistics`).

## Estado
- Publicado: **0.38.0-beta** (tag `v0.38.0-beta`, commit `ab2970c`). Inclui Saga (aba + Leitor), metas de Coleção (montarias/mascotes), memórias do tempo, `/skald report` ampliado, aba Metas redesenhada. `dev` = `main`.
- Leitura em voz alta: implementada, **desligada** (`ns.SpeechOn = false` em `Skald.lua`) porque o usuário achou a voz ruim.
- O usuário ainda precisa testar no jogo: Saga e Metas após reiniciar o jogo; Leitor com export novo; eventos não vistos (PLAYER_DEAD, ENCOUNTER_*, BOSS_KILL, NEW_MOUNT_ADDED) em masmorra/chefe em grupo; convite recusado; montaria/mascote quando o beta tiver; teste com dois jogadores (CHAT_MSG_ADDON entre pessoas).
- Aviso: o diário de teste do usuário pode ter flag errada de grupo recusado (limpar com `/skald clear`).

## Como trabalhar
- Testes: `node dev/tools/checks.js` (sintaxe, texturas, lint, frases en/pt/fr, sessão simulada, regressões, Leitor, velocidade). SEMPRE antes de dizer que algo está pronto. A simulação (fengari/Lua 5.3 + `dev/tools/mock.lua`) NÃO é o jogo: diga isso ao usuário. `node dev/tools/saga_sample.js [loc] [female|male] [level]` imprime uma Saga.
- Release manual (só quando o usuário disser "publica"; eu escolho o número, nada de versões minúsculas): bullets de `dev/NEXT_CHANGELOG.md` -> `CHANGELOG.md` + versão em `Skald.toc`; esvaziar NEXT_CHANGELOG; commit na `dev`; `git checkout main`; `git merge --ff-only dev`; `git push origin main`; `git tag vX.Y.Z-beta`; `git push origin vX.Y.Z-beta`; conferir `gh run list`; voltar à `dev`. (`dev/tools/release.js` ainda está no layout antigo.)
- Commits terminam com as linhas `Co-Authored-By` e `Claude-Session` pedidas pela sessão. Não commitar `teste.pdf` nem `Chronicler addon icon WoW.zip`.
- Regras de Lua/JS, frases (pools ≥ 8, NBSP no francês, palavras proibidas fora de combate), metas (`since` + `GOALS_VERSION`) e arte: ver `CLAUDE.md`.
- Mock: frames devolvem função para chave desconhecida, use `rawget` em campos opcionais. Globais novos do lint vão à mão em `dev/tools/lint_baseline.json`.

## Preferências do usuário
Português; versões escolhidas por ele ou por mim em "publica"; sem integração TRP3; Metas como lista clicável; variedade de frases é desejo permanente; arte é feita por ele no Claude Design (eu escrevo o prompt, ele manda PNG, converto para TGA); personagem feminina, cliente pt-BR, testa também en/fr, com prints; onde o jogo der a estatística direta, usar (fallback: contagem do diário).

## Ideias abertas
Ornamento/letra capitular na Saga (arte), mais capítulos (faixas de nível, cadeias, raras, reencontros, pets), metas de transmog (API não verificada), crônica compartilhada, reativar a voz (flag), abrir `Locales.lua` a tradutores, README/descrição CurseForge/prints, PDF do Leitor girado, campo "Dieta" do pet em outro idioma. Dívida de lint: "unused locals summary" em `Skald.lua` (não falha).
