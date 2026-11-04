# Sons do aviso do Skald: briefing pronto para colar

Use numa ferramenta de efeitos sonoros por texto (ex.: ElevenLabs Sound Effects, Stable Audio) ou como encomenda a quem grava. Gere 4 a 6 variações de cada som e escolha as melhores no ouvido.

## Contexto (cole junto)

```
Efeitos sonoros curtos para um addon de World of Warcraft Classic chamado Skald: um diário épico em primeira pessoa, mostrado como um livro de couro aberto, escrito a pena. O som toca quando um aviso (banner) aparece na tela durante o jogo: uma nova página foi escrita no diário. Deve chamar a atenção sem irritar, tocando centenas de vezes, por cima de combate e música.

Gosto geral: acústico, quente, medieval/fantasia sóbria; livro, pena, cera, pergaminho, sino pequeno, corda dedilhada. Sem voz, sem letras, sem sintetizador moderno, sem 8-bit, sem metal agudo ou estridente, sem reverb longo. Ataque claro (o ouvido percebe em menos de 50 ms), cauda curta, sem silêncio no início.
```

## Os três sons

1. **skald_notice** (normal, missão e página comum): 0,6 a 0,9 s. Um sino de mão pequeno ou nota de lira, uma única nota suave, com um farfalhar de página bem baixo antes. Discreto, mas audível.
2. **skald_major** (nível, conquista, chefe, marco): 1,0 a 1,5 s. Duas ou três notas ascendentes de corda dedilhada ou sino, com um toque de selo de cera. Mais marcante e solene que o normal.
3. **skald_soft** (opcional, uso geral/baixa importância): 0,4 a 0,6 s. Um toque seco de pena sobre pergaminho com um tom curto de madeira. Quase só textura.

## Entrega

- WAV ou MP3/OGG de qualidade, mono ou estéreo, qualquer taxa (eu converto).
- Sem silêncio no início e sem corte seco no fim (cauda com decaimento).
- Nome: `skald_notice`, `skald_major`, `skald_soft`.
- **Licença:** o áudio precisa permitir redistribuição dentro do addon (CurseForge): gerado por ferramenta cujos termos permitam uso comercial/redistribuição, ou CC0. Diga qual ferramenta/licença usou.

## Depois (eu faço)

Converto com ffmpeg para OGG, normalizo, corto o silêncio, coloco em `Sounds/`, ligo ao banner por tipo de página com `PlaySoundFile`, mantenho o liga e desliga de Options, caio no som do jogo se o arquivo faltar e acrescento o teste dos arquivos citados no código. Os arquivos só carregam depois de reiniciar o jogo (não basta `/reload`).
