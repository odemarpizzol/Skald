# Sons do aviso do Skald (v2): prompts para gerador de efeitos sonoros

Problema da v1 (síntese do Codex): sintético e agudo. Meta agora: timbre acústico, quente, grave-médio, de instrumento de verdade. Use ElevenLabs Sound Effects (ou Stable Audio). Gere 4 a 6 versões de cada prompt, escute e mande as melhores.

Dicas para o gerador: prompts curtos e concretos funcionam melhor que longos. Peça a duração na ferramenta (campo de duração), não só no texto. Se vier agudo, acrescente "dark, low register, muffled" e repita.

## Identidade: um motivo de lira

O som do Skald é uma frase curta de lira/alaúde de bardo, em registro médio-grave, em três tamanhos. O mesmo motivo (3 notas ascendentes, ex.: sol-si-ré) nos três, para soarem como família.

## Prompts (copie e cole um por vez)

**skald_notice** (duração 0,8 s)
```
A single soft plucked note on a wooden medieval lute, warm and woody, low-mid register, short natural decay, tiny paper rustle just before it, close microphone, dry, no reverb tail, no synthesizer, no bell, no high-pitched sound
```

**skald_major** (duração 1,5 s)
```
Three ascending plucked notes on a wooden medieval lute or lyre, warm and woody, low-mid register, the last note rings out and fades naturally, subtle soft wax-seal tap at the start, intimate small room, no synthesizer, no choir, no bright or shrill tones
```

**skald_soft** (duração 0,5 s)
```
A quill scratching once on thick parchment followed by one very soft low wooden lute pluck, muffled and warm, dry, quiet, no high frequencies, no synthesizer
```

## Se vier ruim

- Muito agudo/brilhante: acrescente `dark, muffled, low register, bass-heavy lute` (eu também corto agudos depois).
- Muito longo ou com eco: `dry, no reverb, short, abrupt end`.
- Cheio de instrumentos: `solo instrument only, one lute, nothing else`.
- Sintético: `real acoustic recording, wooden instrument, gut strings`.

## Entrega

WAV ou MP3, qualquer taxa. Nomes: `skald_notice`, `skald_major`, `skald_soft` (a versão escolhida) e, se quiser, as outras como `_v1`, `_v2`...
**Licença:** confira nos termos da ferramenta que o áudio gerado pode ser redistribuído em software (CurseForge). Me diga qual ferramenta usou.

## Depois (eu faço)

Passo um filtro que tira os agudos (passa-baixa por volta de 5 kHz), corto o silêncio, normalizo, converto para MP3 em `Sounds/` e troco os sons atuais. O resto do código já está pronto (banner, `/skald sound notice|major|soft`, queda para o som do jogo). Os arquivos só carregam depois de reiniciar o jogo.
