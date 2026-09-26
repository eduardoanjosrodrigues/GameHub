# Avalon — prompts para o Nano Banana

Arte dos personagens e da capa do Avalon (docs/PLANO_AVALON.md §6). Tudo que é simples (fichas, cartas de missão, coroa, Dama, ícone) eu fiz em SVG; aqui estão só as peças que pedem ilustração de verdade.

## Como usar

1. Gere **uma imagem por vez**, colando o **bloco de estilo** e depois o prompt da peça (os dois juntos, na mesma mensagem).
2. Gere o **Merlin primeiro**. Quando ficar bom, anexe ele como **imagem de referência** em todas as outras ("match the style of the attached image exactly"). É isso que deixa o baralho com cara de baralho.
3. Salve com o nome da tabela em `games/avalon/art/roles/` (retratos) ou `games/avalon/art/` (capa e mesa). PNG, JPG ou WEBP servem; se o gerador salvar JPEG com nome `.png`, o `tools/sync_web_assets.sh` arruma a extensão sozinho.
4. Rode `tools/sync_web_assets.sh`: ele arruma a extensão, converte pra WebP qualidade 80 (o que vai no APK e na página do navegador) e guarda o original em `art_originais/`. O app usa a imagem se ela existir; se não, mostra o marcador simples. Se faltar uma variação (ex: `lacaio_3`), usa outra que exista.

Tamanhos: retratos em **2:3 vertical (1024 × 1536)**; capa e mesa em **16:9 (1920 × 1080)**.

Se alguma sair com texto, moldura ou borda, peça de novo: "remove all text, letters, borders and frames". O app desenha a moldura e o nome.

---

## Bloco de estilo (cole antes de cada prompt)

```
Storybook illustration in gouache and ink on warm cream paper, for a modern party card game.
Visible confident black ink linework with slight line-weight variation, flat gouache color fields
with soft dry-brush texture, subtle paper grain. Limited palette: cream paper #F5EFE3, near-black
ink #1F1D1A, cobalt blue #2B59C3, tomato red #C8392B, mustard #F2B233, sage green #2F7D5B, plus
muted skin tones. Warm, witty, slightly stylized proportions (bigger heads and hands, expressive
faces), like a premium European board game — not anime, not 3D, not photorealistic, not pixel art.
Single character, waist-up, three-quarter view, centered, looking toward the viewer, generous empty
space around the figure. Plain cream paper background with a very soft, pale radial vignette, no
scenery, no props floating around. Soft light from the upper left. Absolutely no text, no letters,
no numbers, no logos, no signatures, no borders, no frames, no card edges.
```

---

## Retratos (2:3, `games/avalon/art/roles/`)

| Arquivo | Personagem |
|---|---|
| `merlin.png` | Merlin |
| `percival.png` | Percival |
| `servo_1.png`, `servo_2.png`, `servo_3.png` | Servos leais de Arthur (três pessoas diferentes) |
| `assassino.png` | Assassino |
| `morgana.png` | Morgana |
| `mordred.png` | Mordred |
| `oberon.png` | Oberon |
| `lacaio_1.png`, `lacaio_2.png`, `lacaio_3.png` | Lacaios de Mordred (três pessoas diferentes) |
| `dama_do_lago.png` | Dama do Lago |

### merlin.png

```
Merlin, the old wizard of King Arthur's court, a loyal servant of good. Tall pointed hat and long
robe in deep cobalt blue with small mustard stars embroidered at the hem, long white beard tucked
into a braided mustard cord, bushy eyebrows, kind but knowing eyes that look slightly to the side
as if he knows a secret. One hand holds a gnarled wooden staff topped with a small glowing mustard
crystal; the other hand raises a finger to his lips — "shh". A tiny sage-green owl sits on his
shoulder. Mood: wise, warm, a little mischievous, keeping a secret.
```

### percival.png

```
Sir Percival, a young loyal knight of the Round Table. Short curly auburn hair, clean-shaven, earnest
open face, one eyebrow slightly raised in suspicion. Polished steel breastplate over a cobalt blue
tunic, a round shield with a simple mustard cross strapped on his back. He holds a small hand mirror
up and peers into it, as if trying to see the truth behind two reflections. Mood: loyal, attentive,
a bit puzzled, protective.
```

### servo_1.png

```
A loyal servant of King Arthur: a young woman squire with a short practical bob haircut and freckles,
wearing a simple cobalt blue tabard with a small mustard crown emblem over a cream linen shirt,
leather belt. She holds a short sword upright in front of her chest with both hands, determined
friendly smile. Mood: brave, honest, eager.
```

### servo_2.png

```
A loyal servant of King Arthur: a burly older blacksmith-soldier with a thick grey beard, bald head,
rosy cheeks and laugh lines, wearing a cobalt blue padded gambeson with rolled-up sleeves and a
leather apron, a big hammer resting on his shoulder. Warm trustworthy grin. Mood: steady, reliable,
good-humored.
```

### servo_3.png

```
A loyal servant of King Arthur: a young man with dark skin and short twisted hair, wearing a cobalt
blue hooded cloak over simple chainmail, holding a tall spear with a small mustard pennant. Calm,
serious, watchful expression, eyes slightly narrowed as if studying the table. Mood: calm, sharp,
loyal.
```

### assassino.png

```
The Assassin, a minion of Mordred. Lean figure in a dark hooded cloak of near-black with a tomato
red lining, a red scarf covering the lower half of the face, only sharp eyes visible under the hood.
One gloved hand holds a slim curved dagger low at the side, the other hand points a finger forward
as if choosing a target. Mood: patient, calculating, quietly menacing — but still stylized and
playful, not gory. No blood.
```

### morgana.png

```
Morgana, the enchantress, a minion of Mordred. Elegant woman with long wavy black hair with a streak
of silver, a thin silver circlet with a crescent moon, wearing a deep tomato red gown with a high
collar and a cobalt blue inner lining (to hint she disguises herself as good). She holds a crescent-
shaped hand mirror in which a faint cobalt glow appears. Knowing sly smile, one eyebrow raised.
Mood: charming, deceptive, confident.
```

### mordred.png

```
Mordred, the traitor knight and leader of evil. Handsome young man with sharp cheekbones and slicked
back dark hair, a jagged dark iron crown, black plate armor with tomato red trim and a red cape over
one shoulder. He smiles politely while one hand hides behind his back holding a small black dagger
only the viewer can see. Mood: charismatic, two-faced, arrogant.
```

### oberon.png

```
Oberon, a mysterious lone minion of evil who works apart from the others. A tall pale figure with
long silver-white hair and pointed ears, wearing a tattered near-black cloak with a tomato red hood
pulled back, face half in shadow. His eyes glow faintly mustard; he looks off to the side, isolated,
arms crossed. A few small dry leaves drift around him. Mood: aloof, unpredictable, lonely.
```

### lacaio_1.png

```
A minion of Mordred: a wiry young man with a crooked grin and messy red hair, wearing a patched
near-black leather jerkin with a tomato red armband, holding a lit lantern low, as if sneaking.
Mood: sneaky, nervous, playful villain.
```

### lacaio_2.png

```
A minion of Mordred: a tall stern woman with a severe black braid, a scar across one eyebrow, wearing
a dark iron helmet under her arm and a tomato red surcoat over chainmail, hand resting on a sword
pommel. Cold confident stare. Mood: tough, loyal to evil, intimidating but stylized.
```

### lacaio_3.png

```
A minion of Mordred: a round jolly-looking merchant with a curled mustache, rosy cheeks and a tomato
red velvet hat with a black feather, holding a small pouch of coins close to his chest and winking.
Near-black coat with red buttons. Mood: false friendliness, bribable, comic villain.
```

### dama_do_lago.png

```
The Lady of the Lake. A serene woman rising from still water up to her waist, long flowing hair in
deep sage green that melts into the water, a simple cream dress, and a faint mustard glow behind her
head. She holds up a small round mirror of water that reflects light, offering to reveal the truth.
Soft concentric ripples around her in cobalt blue strokes. Mood: calm, magical, all-seeing.
```

---

## Capa e mesa (16:9, `games/avalon/art/`)

Pra estas, troque no bloco de estilo a parte "Single character, waist-up..." por "Wide scene composition" e mantenha o resto.

### capa.png (tela do jogo no hub e menu)

```
Wide scene: a round wooden table seen from slightly above, in a warm candle-lit stone hall. Around it,
tiny stylized knights and figures lean in close, whispering; in the center of the table lie five
round mission tokens and a golden crown. Two sides are subtly suggested: cobalt blue cloaks on the
left, tomato red cloaks on the right, and one figure in the middle hides a dagger behind his back.
Merlin's pointed cobalt hat peeks from the edge. Keep the top third mostly empty warm background for
the app to place the title. Mood: cozy, suspicious, playful.
```

### mesa.png (fundo do tabuleiro, fica atrás de tudo)

```
Top-down view of an empty round wooden table with carved rune-like border patterns, on warm cream
paper background, very low contrast and soft so text and tokens can sit on top of it. Five empty
circular recesses in an arc near the top edge (for mission tokens) and a small row of five tiny
circles along the bottom (for the rejection track). No figures, no objects. Muted, calm, mostly
cream and light wood tones with thin ink lines.
```
