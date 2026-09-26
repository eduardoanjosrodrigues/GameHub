# Coup — prompts para o Nano Banana

Retratos dos personagens, capa e fundo do tabuleiro (docs/PLANO_COUP.md §6). Moedas, verso da carta, emblemas e ícone já estão prontos em SVG. Enquanto os retratos não existem, a carta mostra o emblema na cor do personagem.

## Como usar

1. Gere **uma imagem por vez**. Cole o **bloco de estilo** e depois o prompt da peça, os dois na mesma mensagem.
2. Gere o **Duque 1** primeiro. Quando ficar bom, anexe ele como **imagem de referência** em todas as outras e escreva "match the style of the attached image exactly". Para o Coup ter cara de família com o Avalon, anexe também o Merlin.
3. Salve com o nome da tabela em `games/coup/art/`. PNG, JPG ou WEBP servem.
4. Rode `tools/sync_web_assets.sh`. Ele converte para WebP, que é o que vai no APK, e guarda o original em `art_originais/`.

Tamanhos:
- Retratos: **vertical, perto de 10:13 (1000 × 1300)**. Um 2:3 (1024 × 1536) também serve: o app recorta um pouco em cima e embaixo.
- Capa e mesa: **16:9 (1920 × 1080)**.

Cada personagem tem 2 variações; cada jogador vê a sua, para a mesa não ficar repetida. Se faltar uma, o app usa a outra.

Se alguma sair com texto, moldura ou borda, peça de novo: "remove all text, letters, borders and frames". O nome e a faixa colorida quem desenha é o app.

---

## Bloco de estilo (cole antes de cada prompt)

```
Storybook illustration in gouache and ink on warm cream paper, for a modern party card game about
intrigue in a Renaissance Italian court. Visible confident black ink linework with slight
line-weight variation, flat gouache color fields with soft dry-brush texture, subtle paper grain.
Limited palette: cream paper #F5EFE3, near-black ink #1F1D1A, royal purple #6E3B93, cobalt blue
#2B59C3, sage green #2F7D5B, burnt orange #D9772B, tomato red #C8392B, mustard gold #F2B233, plus
muted skin tones. Witty, slightly stylized proportions (bigger heads and hands, expressive faces),
like a premium European board game — not anime, not 3D, not photorealistic, not pixel art.
Fictional characters only, no real people, no religious symbols. Single character, waist-up,
three-quarter view, centered, looking toward the viewer with a knowing, scheming expression,
generous empty space around the figure. Plain cream paper background with a very soft, pale
radial vignette, no scenery. Soft light from the upper left. Absolutely no text, no letters, no
numbers, no logos, no signatures, no borders, no frames, no card edges.
```

---

## Retratos (vertical, `games/coup/art/`)

Cada personagem puxa para uma cor, a mesma da faixa da carta:

| Arquivos | Personagem | Cor |
|---|---|---|
| `duque_1.jpg`, `duque_2.jpg` | Duque | roxo |
| `assassino_1.jpg`, `assassino_2.jpg` | Assassino | quase preto |
| `capitao_1.jpg`, `capitao_2.jpg` | Capitão | azul |
| `embaixador_1.jpg`, `embaixador_2.jpg` | Embaixador | verde |
| `inquisidor_1.jpg`, `inquisidor_2.jpg` | Inquisidor (variante) | laranja |
| `condessa_1.jpg`, `condessa_2.jpg` | Condessa | vermelho |

### duque_1.jpg

```
The Duke: a plump, self-satisfied older nobleman with a trimmed grey beard and heavy-lidded eyes,
wearing a royal purple velvet robe with a thick fur collar and a small gold coronet, one hand
resting on a bulging coin purse, a sly smile. Mood: rich, smug, taxing everyone.
```

### duque_2.jpg

```
The Duke: a tall, thin younger nobleman with slicked black hair and a pencil mustache, wearing a
royal purple doublet with gold embroidery and a heavy gold chain, counting gold coins from one
hand to the other with a greedy grin. Mood: calculating, ambitious.
```

### assassino_1.jpg

```
The Assassin: a lean figure in a near-black hooded cloak, the lower face covered by a dark scarf,
sharp amber eyes visible under the hood, holding a thin silver dagger low at the side, one gloved
finger raised to the lips. Mood: silent, dangerous, playful menace — stylized, not gory.
```

### assassino_2.jpg

```
The Assassin: a young woman with a short dark braid and a mischievous smirk, wearing a fitted
near-black leather jerkin and a short cape, twirling a small curved dagger between her fingers,
one eyebrow raised. Mood: quick, confident, a little cheeky — no blood.
```

### capitao_1.jpg

```
The Captain: a broad-shouldered sea captain with a bushy red-brown beard and a scar on one cheek,
wearing a cobalt blue coat with brass buttons and a tricorn hat, a hand on the hilt of a sheathed
cutlass, grinning as if about to take your coins. Mood: bold, rough, charming bully.
```

### capitao_2.jpg

```
The Captain: a sharp-eyed woman officer with a high ponytail and a small gold earring, wearing a
cobalt blue military jacket with gold epaulettes, holding out an open palm toward the viewer as
if demanding payment, a confident half smile. Mood: commanding, sly.
```

### embaixador_1.jpg

```
The Ambassador: a smooth, elegant diplomat with a neat silver goatee and round spectacles, wearing
a sage green silk robe with a high collar, holding a sealed scroll with a red wax seal and
offering it with a polite, knowing bow of the head. Mood: courteous, two-faced, clever.
```

### embaixador_2.jpg

```
The Ambassador: a young diplomat with curly brown hair and a charming smile, wearing a sage green
doublet with a cream lace collar, fanning out a few folded letters like playing cards in one
hand. Mood: persuasive, trading secrets.
```

### inquisidor_1.jpg

```
The Inquisitor: a stern, gaunt older man with piercing eyes and a hooked nose, wearing a burnt
orange hooded robe with a plain dark sash (no religious symbols), holding a small magnifying
glass up to one eye, which appears huge through the lens. Mood: suspicious, investigating,
slightly comic.
```

### inquisidor_2.jpg

```
The Inquisitor: a severe middle-aged woman with a tight grey bun and narrow reading glasses,
wearing a burnt orange high-collared robe (no religious symbols), holding an open ledger and a
quill, peering at the viewer over her glasses. Mood: "I know what you're hiding."
```

### condessa_1.jpg

```
The Countess: an elegant noblewoman with auburn hair piled high and a beauty mark, wearing a
tomato red silk gown with a lace collar and a pearl necklace, holding a folding fan half open in
front of her smile, eyes amused. Mood: untouchable, graceful, protected.
```

### condessa_2.jpg

```
The Countess: a young noblewoman with long dark wavy hair and a small tiara, wearing a tomato red
velvet dress with gold trim, holding a single red rose and raising one hand in a calm "stop"
gesture. Mood: serene, commanding, nobody touches her.
```

---

## Capa e mesa (16:9, `games/coup/art/`)

Para estas duas, troque no bloco de estilo o trecho "Single character, waist-up… generous empty space around the figure." por "Wide scene composition." e mantenha o resto.

### capa.jpg (menu do jogo e sala do navegador)

```
Wide scene: a candlelit Renaissance palace hall. Around a long table covered with gold coins and
face-down cards, six scheming courtiers lean in and whisper behind their hands: a plump duke in
purple, a hooded assassin in black, a sea captain in blue, a diplomat in green with a scroll, an
inquisitor in orange with a magnifying glass, and a countess in red with a fan. Everyone is
secretly pointing at someone else. Keep the top third mostly empty warm background for the app
to place the title. Mood: tense, sneaky, fun.
```

### mesa.jpg (fundo do tabuleiro, fica bem clarinho atrás de tudo)

```
Top-down view of an empty polished dark wooden table with a faded burgundy velvet runner, a few
scattered gold coins and a brass candlestick at the edges, on warm cream background. Very low
contrast and soft, mostly cream and light wood tones with thin ink lines, so cards and text can
sit on top. The center is completely empty. No people, no text, no symbols.
```
