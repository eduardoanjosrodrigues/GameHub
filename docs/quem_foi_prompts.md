# Quem Foi? — prompts para o Nano Banana

Arte dos bichos, do cocô, da capa e do fundo do tabuleiro (docs/PLANO_QUEM_FOI.md §6). A cor de cada jogador, os nomes e os textos quem desenha é o app: as imagens não têm coleira, moldura nem letra.

## Como usar

1. Gere **uma imagem por vez**. Cole o **bloco de estilo** e depois o prompt da peça, os dois na mesma mensagem.
2. Gere o **gato** primeiro. Quando ficar bom, anexe ele como **imagem de referência** em todas as outras e escreva "match the style of the attached image exactly". Se quiser que o jogo tenha cara de família com o Avalon, anexe também o Merlin.
3. Salve com o nome da tabela em `games/quem_foi/art/`. PNG, JPG ou WEBP servem.
4. Rode `tools/sync_web_assets.sh`. Ele converte para WebP, que é o que vai no APK, e guarda o original em `art_originais/`.

Tamanhos:
- Bichos e cocô: **quadrados (1024 × 1024)**. Na mão, as cartas ficam lado a lado e precisam ser reconhecidas num relance.
- Capa e mesa: **16:9 (1920 × 1080)**.

O app usa a imagem se ela existir; se não existir, mostra um bicho simples em SVG.

Se alguma sair com texto, moldura, coleira ou borda, peça de novo: "remove all text, letters, collars, borders and frames".

---

## Bloco de estilo (cole antes de cada prompt)

```
Storybook illustration in gouache and ink on warm cream paper, for a modern family party card game.
Visible confident black ink linework with slight line-weight variation, flat gouache color fields
with soft dry-brush texture, subtle paper grain. Limited palette: cream paper #F5EFE3, near-black
ink #1F1D1A, cobalt blue #2B59C3, tomato red #C8392B, mustard #F2B233, sage green #2F7D5B, plus
natural animal colors kept soft and muted. Cute, funny, slightly chubby stylized pets with big
expressive eyes, like a premium European family board game — not anime, not 3D, not
photorealistic, not pixel art, not babyish clip art. Single animal, full body, centered, filling
about 70% of a square frame, with a clear, instantly readable silhouette. The pet makes an overly
innocent face ("who, me?") with a tiny hint of guilt. No collar, no clothes, no accessories.
Plain cream paper background with a very soft, pale radial vignette, no floor, no scenery.
Soft light from the upper left. Absolutely no text, no letters, no numbers, no logos, no
signatures, no borders, no frames, no card edges.
```

---

## Bichos (1:1, `games/quem_foi/art/`)

Cada bicho tem uma **cor dominante diferente**, para ninguém confundir na corrida: laranja, azul, verde, cinza, dourado e vermelho.

| Arquivo | Bicho | Cor que domina |
|---|---|---|
| `gato.jpg` | Gato | laranja (gato malhado ruivo) |
| `peixe.jpg` | Peixe | azul (água do aquário) |
| `tartaruga.jpg` | Tartaruga | verde |
| `coelho.jpg` | Coelho | cinza e branco |
| `hamster.jpg` | Hamster | dourado |
| `papagaio.jpg` | Papagaio | vermelho (arara) |

### gato.jpg

```
A chubby orange tabby cat sitting upright with its tail neatly wrapped around its paws, head
slightly tilted, huge round innocent eyes looking up at the viewer, whiskers perky, one ear
twitching. Mood: "I would never do such a thing."
```

### peixe.jpg

```
A round goldfish bowl with a small plump fish inside, seen from the front. The bowl water is a
clear soft cobalt blue, a couple of tiny bubbles rising, a little green water plant at the bottom.
The fish is a pale peach-orange with big innocent eyes and puffed cheeks, fins spread as if
shrugging. Mood: "I live in a bowl, how could it be me?"
```

### tartaruga.jpg

```
A small round tortoise standing on its four stubby legs, seen in three-quarter view, with a sage
green shell with a simple hexagon pattern and a mustard-tinted belly. Its head is stretched out,
eyes half-closed and very calm, a tiny smug smile. Mood: "I'm far too slow to be guilty."
```

### coelho.jpg

```
A fluffy grey-and-white bunny sitting on its hind legs, long ears straight up with one ear flopping
at the tip, tiny front paws held together against its chest, nose twitching, big shiny innocent
eyes. Mood: "Me? I only eat carrots."
```

### hamster.jpg

```
A round golden hamster standing on its hind legs, cheeks comically stuffed full like two balloons,
tiny paws raised as if caught in the act, big black shiny eyes wide open. Mood: "Mmph? Nothing to
see here."
```

### papagaio.jpg

```
A scarlet macaw parrot perched on a short simple wooden perch, bright tomato red body with a few
cobalt blue and mustard wing feathers, head turned to the side with one eye looking at the viewer,
beak slightly open as if about to talk its way out of trouble. Mood: "Squawk! It wasn't me!"
```

---

## O cocô (1:1, `games/quem_foi/art/coco.jpg`)

Aparece no meio da mesa e no placar de cocôs.

```
A single cartoon poop swirl, soft chocolate brown with three neat coils and a rounded tip, a small
cream highlight on top, sitting on the cream background with three tiny wavy stink lines above it
drawn in thin ink. Cute and silly, not gross, no face, no flies. Centered, filling about 60% of the
square frame.
```

---

## Capa e mesa (16:9, `games/quem_foi/art/`)

Para estas duas, troque no bloco de estilo o trecho "Single animal, full body, centered… No collar,
no clothes, no accessories." por "Wide scene composition." e mantenha o resto.

### capa.jpg (menu do jogo e sala do navegador)

```
Wide scene: a cozy living room seen from a low angle. In the middle of a round rug sits one cartoon
poop swirl with tiny stink lines. Around it, the six pets — an orange tabby cat, a goldfish in a
round bowl, a green tortoise, a grey-and-white bunny, a golden hamster with stuffed cheeks and a
red macaw on a perch — all look away, whistle or point at each other with exaggerated innocent
faces. A sofa and a lamp in the background, simple and soft. Keep the top third mostly empty warm
background for the app to place the title. Mood: funny, chaotic, family-friendly.
```

### mesa.jpg (fundo do tabuleiro, fica bem clarinho atrás de tudo)

```
Top-down view of a round woven living room rug on a light wooden floor, with a couple of scattered
pet toys at the edges (a yarn ball, a chew bone, a small feather). The center is completely empty.
Very low contrast and soft, mostly cream and light wood tones with thin ink lines, so cards and
text can sit on top. No animals, no poop, no text.
```

---

## Opcional: o culpado (1:1)

Na hora do "Ninguém tem mais coelho!", o app pode mostrar o bicho culpado com cara de pego no flagra. Se quiser, gere a versão "culpada" de cada bicho com o mesmo prompt dele, trocando a última frase ("Mood: …") por:

```
Mood: caught red-handed — ears down, sheepish guilty grin, eyes looking sideways, a tiny sweat
drop, one small cartoon poop swirl on the cream background next to it.
```

Salve como `gato_culpado.jpg`, `peixe_culpado.jpg` e assim por diante. Se não existirem, o app usa o bicho normal com um cocô desenhado ao lado.
