# Secret Hitler — prompts para o Nano Banana

Arte dos papéis, da capa e do fundo do tabuleiro (docs/PLANO_SECRET_HITLER.md §6). Tudo que é simples (cartas de lei, cédulas Ja!/Nein, cartão de partido, ícones dos poderes, ícone do jogo) eu fiz em SVG; aqui estão só as peças que pedem ilustração de verdade.

**Arte neutra**: nada de suástica, braçadeira, águia, uniforme militar, bandeira ou rosto de pessoa real. Os prompts já dizem isso; se sair algum símbolo, peça de novo.

## Como usar

1. Gere **uma imagem por vez**, colando o **bloco de estilo** e depois o prompt da peça (os dois juntos, na mesma mensagem).
2. Gere o **Liberal 1 primeiro**. Quando ficar bom, anexe ele como **imagem de referência** em todas as outras ("match the style of the attached image exactly"). Se quiser o baralho com cara de família do Avalon, anexe também o Merlin.
3. Salve com o nome da tabela em `games/secret_hitler/art/roles/` (retratos) ou `games/secret_hitler/art/` (capa e mesa). PNG, JPG ou WEBP servem.
4. Rode `tools/sync_web_assets.sh` (arruma a extensão e marca as imagens pra irem no APK e na página do navegador).

Tamanhos: retratos em **2:3 vertical (1024 × 1536)**; capa e mesa em **16:9 (1920 × 1080)**. O app usa a imagem se ela existir; se não, mostra o marcador (ramo de oliveira, caveira ou chapéu). Se faltar uma variação (ex: `liberal_4`), usa outra que exista.

Se alguma sair com texto, moldura ou borda, peça de novo: "remove all text, letters, borders and frames". O app desenha a moldura e o nome.

---

## Bloco de estilo (cole antes de cada prompt)

```
Storybook illustration in gouache and ink on warm cream paper, for a modern party card game,
with the mood of a 1930s political drama poster. Visible confident black ink linework with slight
line-weight variation, flat gouache color fields with soft dry-brush texture, subtle paper grain.
Limited palette: cream paper #F5EFE3, near-black ink #1F1D1A, cobalt blue #2B59C3, tomato red
#C8392B, mustard #F2B233, sage green #2F7D5B, plus muted skin tones. Warm, witty, slightly
stylized proportions (bigger heads and hands, expressive faces), like a premium European board
game — not anime, not 3D, not photorealistic, not pixel art. Fictional characters only: no real
people, no historical figures, no flags, no insignia, no armbands, no military uniforms, no
political symbols of any kind. Single character, waist-up, three-quarter view, centered, looking
toward the viewer, generous empty space around the figure. Plain cream paper background with a
very soft, pale radial vignette, no scenery. Soft light from the upper left. Absolutely no text,
no letters, no numbers, no logos, no signatures, no borders, no frames, no card edges.
```

---

## Retratos (2:3, `games/secret_hitler/art/roles/`)

| Arquivo | Personagem |
|---|---|
| `liberal_1.jpg` … `liberal_4.jpg` | Liberais (quatro pessoas diferentes) |
| `fascista_1.jpg` … `fascista_3.jpg` | Fascistas (três pessoas diferentes) |
| `hitler.jpg` | O Hitler (figura misteriosa, rosto na sombra) |

Liberais puxam pro **cobalto**; fascistas pro **tomate**; o Hitler pro **quase preto com um toque de tomate**.

### liberal_1.jpg

```
A liberal politician of the 1930s: a young woman journalist with a short wavy bob, round
glasses and a warm determined smile, wearing a cobalt blue blazer over a cream blouse, a
notebook and pencil in her hands, a small press card tucked in her hat band. Mood: honest,
curious, brave.
```

### liberal_2.jpg

```
A liberal politician of the 1930s: an older gentleman with a white walrus mustache, bushy
eyebrows and kind tired eyes, wearing a cobalt blue three-piece suit with a pocket watch chain,
holding rolled-up papers under one arm and raising the other hand as if giving a heartfelt
speech. Mood: principled, grandfatherly, stubborn.
```

### liberal_3.jpg

```
A liberal politician of the 1930s: a young man with dark skin, short neat hair and a thin
mustache, wearing a cobalt blue waistcoat with rolled-up shirt sleeves and suspenders, holding a
stack of pamphlets and leaning forward with an eager open expression. Mood: idealistic, energetic,
trustworthy.
```

### liberal_4.jpg

```
A liberal politician of the 1930s: a middle-aged woman with a grey streaked bun, pearl earrings
and a sharp skeptical look, wearing a cobalt blue dress with a cream collar, arms crossed while
holding a pair of reading glasses. Mood: wise, suspicious, fair.
```

### fascista_1.jpg

```
A villainous schemer of the 1930s: a slick young man with oiled-back black hair, a thin smile
and narrowed eyes, wearing a tomato red double-breasted suit with a black tie, lighting a
cigarette with a match while glancing sideways. Mood: charming, sneaky, dangerous — stylized and
playful, not grim.
```

### fascista_2.jpg

```
A villainous schemer of the 1930s: a tall severe woman with a dark sleek bob, bright red
lipstick and one raised eyebrow, wearing a tomato red coat with a black fur collar, holding a
folded secret note between two gloved fingers. Mood: cold, elegant, manipulative.
```

### fascista_3.jpg

```
A villainous schemer of the 1930s: a heavyset jovial businessman with a round face, a monocle
and a big fake smile, wearing a tomato red vest over a near-black suit, rubbing his hands
together greedily. Mood: false friendliness, greedy, comic villain.
```

### hitler.jpg

```
A mysterious fictional mastermind in the shadows: a figure in a long near-black trench coat with
the collar turned up and a dark wide-brimmed fedora hat pulled low with a tomato red hat band;
the whole face is hidden in deep shadow except two small faintly glowing mustard eyes. One gloved
hand rests on the brim of the hat. No mustache, no recognizable face, no real person, no symbols.
Mood: secret, patient, ominous — stylized like a noir board game villain.
```

---

## Capa e mesa (16:9, `games/secret_hitler/art/`)

Pra estas, troque no bloco de estilo a parte "Single character, waist-up..." por "Wide scene composition" e mantenha o resto.

### capa.jpg (menu do jogo e sala do navegador)

```
Wide scene: a smoky 1930s parliament meeting room seen from slightly above, a long wooden table
under a hanging lamp. Around it, stylized politicians in cobalt blue and tomato red suits lean in,
whispering and pointing at each other; papers and two stamped decrees (one cobalt with an olive
branch, one red with a small skull) lie on the table. In the back, in the shadow of a doorway,
a mysterious figure in a fedora with a red hat band watches with faintly glowing eyes. Keep the
top third mostly empty warm background for the app to place the title. No flags, no insignia, no
real people. Mood: tense, suspicious, playful.
```

### mesa.jpg (fundo do tabuleiro, fica bem clarinho atrás de tudo)

```
Top-down view of an empty dark wooden desk with a green leather blotter, a few scattered blank
papers, an old rotary telephone and an ink pot at the edges, on warm cream paper background, very
low contrast and soft so text and cards can sit on top of it. The center is mostly empty. No
figures, no text, no symbols. Muted, calm, mostly cream and light wood tones with thin ink lines.
```
