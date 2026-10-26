# Skald: handoff para o Claude Code (2026-10-25)

Addon de World of Warcraft (família Classic), diário épico em primeira pessoa mostrado como um livro de couro aberto. O repo mantém `## Interface: 16001`; o cliente de teste atual é o Anniversary (TOC 20506 só na cópia). Os textos saem em en/ptBR/frFR.
Autor Oddynho, MIT, CurseForge ID 1748824. Respostas ao usuário SEMPRE em português (pt-br).

## Onde está tudo
- Espaço oficial: `/home/odemarpizzol/work/dpzl/projects/Skald/Skald` (a pasta deve se chamar `Skald`; as ferramentas resolvem o addon como `<pai do repo>/Skald`). Branch `dev` = trabalho; `main` = publicação.
- O jogo lê de `D:\Games\World of Warcraft\_anniversary_\Interface\AddOns\Skald` (= `/mnt/d/Games/World of Warcraft/_anniversary_/Interface/AddOns/Skald`). Copie só o que mudou (cp + cmp); o `Skald.toc` da cópia leva `## Interface: 20506`. `/reload` basta, exceto textura nova (reiniciar o jogo). NUNCA copie a `dev` para `_retail_`: o retail tem a branch `retail` e um worktree próprio (`../Skald-Retail/Skald`, TOC 120105, versão `-retail-alpha`).
- Repo: https://github.com/odemarpizzol/Skald. Leitor web: https://odemarpizzol.github.io/Skald/reader/ (GitHub Pages serve `docs/` da `main`).
- Plano grande do usuário: `refactored-discovering-aurora.md` (Saga, crônica compartilhada, TTS, memórias do tempo).
- Memória do Claude: `~/.claude-personal/projects/-home-odemarpizzol-work-dpzl-projects-Skald-Skald/memory/` (regra `prefer-game-statistics`).

## Estado
- Publicado: **0.40.0-beta** (selos de cera por facção, rabiscos de clima e do dia, página "O dia em números"). A `dev` está à frente da `main` com: densidade das páginas (`/skald density` e botões na aba Estilo), rabiscos espalhados por `ns.DoodleSpot`, 19 metas de longo prazo (versão 4 da lista) com 3 títulos acima de 750 pontos e paginação da lista de metas. Tudo isso consta em `dev/NEXT_CHANGELOG.md` e **ainda não foi publicado**.
- Leitura em voz alta: implementada, **desligada** (`ns.SpeechOn = false` em `Skald.lua`) porque o usuário achou a voz ruim.
- O usuário ainda precisa testar no jogo (`/reload`): densidade (botões do Estilo, comando, letra e rabiscos por densidade), a aba Metas (paginador `< 1/2 >`, dias em A Estrada), selo por facção, página "O dia em números"; e os eventos não vistos (PLAYER_DEAD, ENCOUNTER_*, BOSS_KILL, NEW_MOUNT_ADDED) em masmorra/chefe em grupo, convite recusado, teste com dois jogadores (CHAT_MSG_ADDON).
- Aviso: o diário de teste do usuário pode ter flag errada de grupo recusado (limpar com `/skald clear`).

## Como trabalhar
- Testes: `node dev/tools/checks.js` (sintaxe, texturas, lint, frases en/pt/fr, sessão simulada, regressões, Leitor, velocidade). SEMPRE antes de dizer que algo está pronto. A simulação (fengari/Lua 5.3 + `dev/tools/mock.lua`) NÃO é o jogo: diga isso ao usuário. `node dev/tools/saga_sample.js [loc] [female|male] [level]` imprime uma Saga.
- Release manual (só quando o usuário disser "publica"; eu escolho o número, nada de versões minúsculas): bullets de `dev/NEXT_CHANGELOG.md` -> `CHANGELOG.md` + versão em `Skald.toc`; esvaziar NEXT_CHANGELOG; commit na `dev`; `git checkout main`; `git merge --ff-only dev`; `git push origin main`; `git tag vX.Y.Z-beta`; `git push origin vX.Y.Z-beta`; conferir `gh run list`; voltar à `dev`. (`dev/tools/release.js` ainda está no layout antigo.)
- Commits terminam com a linha `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Não commitar `teste.pdf` nem `Chronicler addon icon WoW.zip`.
- Regras de Lua/JS, frases (pools ≥ 8, NBSP no francês, palavras proibidas fora de combate), metas (`since` + `GOALS_VERSION`) e arte: ver `CLAUDE.md`.
- Mock: frames devolvem função para chave desconhecida, use `rawget` em campos opcionais. Globais novos do lint vão à mão em `dev/tools/lint_baseline.json`.

## Preferências do usuário
Português; versões escolhidas por ele ou por mim em "publica"; sem integração TRP3; Metas como lista clicável; variedade de frases é desejo permanente; arte é feita por ele no Claude Design (eu escrevo o prompt, ele manda PNG, converto para TGA); personagem feminina, cliente pt-BR, testa também en/fr, com prints; onde o jogo der a estatística direta, usar (fallback: contagem do diário).

## Ideias abertas
Ornamento/letra capitular na Saga (arte), mais capítulos (faixas de nível, cadeias, raras, reencontros, pets), metas de transmog (API não verificada), crônica compartilhada, reativar a voz (flag), abrir `Locales.lua` a tradutores, README/descrição CurseForge/prints, PDF do Leitor girado, campo "Dieta" do pet em outro idioma. Dívida de lint: "unused locals summary" em `Skald.lua` (não falha). Arte pendente (o usuário faz no Claude Design): emblemas `pt_title6..8` para os 3 títulos novos (hoje reaproveitam o `pt_title5`), papéis com desgaste em formato retrato, selo da Horda mais distinto do Neutro, nota solta estilizada. Código: clima real (precisa de cliente que o exponha), retail (`Compat.lua`, metas/tiers por flavor), módulo hardcore (verificar APIs no jogo antes), `dev/tools/release.js` ainda no layout antigo (`Skald-publish`). Desempenho com 3000 páginas é medido em fengari (abrir ~500 ms, export ~600 ms, texto do Leitor ~1,4 s), bem mais lento que o jogo: sem alvo claro para otimizar.
- Aviso sonoro do banner: já existe o som de virar página ao aparecer o aviso, ligado/desligado em Opções ("Som ao virar a página", `SkaldDB.sound`). Se o usuário quiser um som próprio só para o banner, é uma opção separada (escolher um `SOUNDKIT` do cliente e testar no jogo).
- Prompt de arte pronto: `dev/PROMPT_ARTE_titulos_novos.md` (emblemas `pt_title6..8`).
