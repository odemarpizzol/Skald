# Skald: handoff para o Claude Code (2026-10-21)

Addon de World of Warcraft "Forever" (beta, `## Interface: 16001`), diario epico em primeira pessoa mostrado como um livro de couro aberto.
Autor Oddynho, MIT, CurseForge ID 1748824. Respostas ao usuario SEMPRE em portugues.

## Onde esta tudo
- Addon (pasta viva do jogo, edito direto): `D:\Games\World of Warcraft\_classic_beta_\Interface\AddOns\Skald\` (Skald.lua ~6300 linhas, Locales.lua en/pt/fr, Goals.lua, Atlas.lua (mapa embutido), Curated.lua, XPTiers.lua, Textures\).
- Publicacao/ferramentas: `D:\Games\World of Warcraft\_classic_beta_\Skald-publish\` (tools\, NEXT_CHANGELOG.md, ROTEIRO_TESTE_0.37.md, art\).
- Repo GitHub (publico): `Skald-publish\skald-repo` -> https://github.com/odemarpizzol/Skald (branch main). Leitor web em `skald-repo\docs\reader` (GitHub Pages: main, /docs) -> https://odemarpizzol.github.io/Skald/reader/
- Plano grande: `C:\Users\odema\.claude\plans\refactored-discovering-aurora.md` (Marcos: 2 Saga, 3 cronica compartilhada, 4 leitura por TTS, 5 memorias do tempo).
- Memoria do projeto: `C:\Users\odema\.claude\projects\D--Games-World-of-Warcraft--classic-beta-\memory\` (leia MEMORY.md e chronicler-project-state.md).

## Estado
- Publicado: 0.37.0-beta (tag v0.37.0-beta). Ja no repo local/GitHub: tudo ate o design de abas (Estilo / Avisos / Opcoes), raridade de chefes, minimapa garantido.
- NAO publicado ainda (esta so na pasta do jogo e no NEXT_CHANGELOG.md): pagina de Pets nova com icones de familia (17 PNG do usuario convertidos para `Textures\pet_<familia>.tga`, tabela `K.FAMILY_BOX` com o recorte de cada um, `Mile.SetFamilyIcon`, flag `K.OWN_PET_ART = true`), e o balao do Leitor ao passar o mouse em missao/item (campo 9 do export `K.ReaderInfo`, `reader.js` attachTip, clique abre Wowhead Classic). Proxima versao sugerida: 0.37.1-beta (o usuario escolhe o numero; "publica" = eu escolho).
- O usuario ainda precisa testar no jogo: fases 8, 9, 11, 12, 13 do roteiro (chefe apos quedas, reencontro/lembranca, nomes ocultos, mapa, idiomas) e ver a pagina de Pets com os icones novos (precisa reiniciar o jogo por completo, nao so /reload).
- Itens pequenos pendentes: crocolisco/gato/raptor encostam na borda direita (pedir 8% de folga ao design); fase 6 (ofícios "N de ...") nao foi vista pelo usuario.

## Como trabalhar
- Testes: `cd Skald-publish && node tools/checks.js` (sintaxe, texturas, lint, frases en/pt/fr, sessao simulada, regressoes, Leitor, velocidade). SEMPRE rode antes de dizer que algo esta pronto. A simulacao (fengari/Lua 5.3) NAO e o jogo: diga isso ao usuario.
- Release: escrever bullets em `NEXT_CHANGELOG.md` (ingles), `node tools/release.js <versao>` (checks + toc + CHANGELOG + zip + copia para skald-repo), esvaziar NEXT_CHANGELOG.md, no `skald-repo`: `git add -A && git commit`, `git push origin main`, `git tag v<versao>`, `git push origin v<versao>`. O GitHub Actions (BigWigs packager, secret CF_API_KEY ja configurado) envia ao CurseForge. So publicar quando o usuario disser "publica". Commit termina com a linha Co-Authored-By pedida pela sessao.
- Zips sao feitos com `C:\Windows\System32\tar.exe -a -cf` (o tar do Git Bash gera zip sem compressao).
- Texturas novas: TGA 32 bits, potencia de 2, em `Textures\`; so aparecem no jogo apos reiniciar o jogo por completo.
- Lua 5.1 do cliente: limite de 200 locals no chunk principal de Skald.lua (hoje ~145; constantes e helpers ficam nas tabelas `K`, `Mile`, `ns`); sem escapes `\u`.
- Shell come barras invertidas: escreva Lua/JS com escapes usando as ferramentas Write/Edit, nao heredoc/`node -e`.
- O texto das paginas e montado ao vivo (`PoolFor`/`RenderEntry`); entradas guardam IDs e `idx`. Frases novas: sempre nos 3 idiomas (en/pt/fr) e sem repetir frase (janela anti-repeticao 5).
- Servidor de preview do Leitor: `.claude\launch.json` em `_classic_beta_` (nome `reader`, porta 8765).

## Preferencias do usuario
Responder em portugues; versoes escolhidas por ele; nada de versoes minusculas; sem integracao com TRP3 por enquanto; Metas como lista clicavel (nao virar pagina); variedade de frases e desejo permanente; arte e feita por ele no Claude Design (peco prompt + ele manda zip em `Interface\Chronicler addon icon WoW.zip` ou Downloads; converto com sharp para TGA); o usuario joga personagem feminina (cliente pt-BR; testa tambem en/fr) e testa no jogo com prints.
