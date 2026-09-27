# Ícone do app — prompts para o Nano Banana

Hoje o ícone é a cartola do Chapéu. O novo é um **leque de 4 cartas** nas cores do app, sem texto, no mesmo guache dos jogos, para não ser de nenhum jogo em particular.

## Como usar

1. Cole o **bloco de estilo** e depois **uma** das variações, os dois na mesma mensagem. Gere umas 3 de cada variação que você gostar.
2. Para ficar com cara de família, anexe o **Duque 1** do Coup (`art_originais/coup/art/duque_1.jpg`) e escreva "match the painting style of the attached image, but not its subject".
3. Salve a escolhida como `art_originais/app_icon/app_icon_art.png` (ou `.jpg`), quadrada, de 1024 × 1024 para cima. As outras podem ficar na mesma pasta: ela não vai para o APK.
4. Rode `python3 tools/app_icon.py`: ele separa o fundo, encaixa o desenho na área que o Android não recorta e gera os tamanhos em `design/store/`.

Por que o desenho tem que ficar no meio: o Android recorta o ícone em círculo, quadrado arredondado ou gota, conforme o aparelho, e corta até 1/6 de cada borda. Por isso o prompt pede as cartas dentro dos 60% do meio e o fundo liso de ponta a ponta.

Se sair com texto, moldura, borda ou cantos arredondados, peça de novo: "remove all text, letters, borders and frames; the background must be flat mustard yellow edge to edge".

---

## Bloco de estilo (cole antes de cada variação)

```
App icon for a party card-game app, square 1:1. Storybook illustration in gouache and ink: visible
confident black ink linework with slight line-weight variation, flat gouache color fields with soft
dry-brush texture, like a premium European board game — not 3D, not glossy, not photorealistic, not
anime, not pixel art, no gradients. Bold, simple silhouette that stays readable at 48 pixels: few
shapes, thick outlines, strong contrast. The background is one completely flat, uniform mustard
yellow #F2B233 filling the whole square edge to edge, with no vignette, no shadow gradient, no
texture, no scenery. The whole drawing fits inside the central 60% of the square, with generous
empty mustard margin on every side. Palette: tomato red #C8392B, cobalt blue #2B59C3, sage green
#2F7D5B, cream paper #FFFCF6, near-black ink #1F1D1A. Absolutely no text, no letters, no numbers,
no logos, no borders, no frames, no rounded-square badge, no drop shadow outside the drawing.
```

---

## Variação A — estrela (a minha preferida)

```
Four playing cards fanned out like a hand being shown, slightly tilted, their bottom corners
meeting at one point. From back to front the card faces are: sage green, cobalt blue, tomato red,
and the front card is cream. Each colored card has only a thin cream inner border and no symbols.
The front cream card has a single big, chunky five-pointed star in mustard gold with a thick black
outline in its center. A tiny soft shadow under each card. Mood: cheerful, inviting, "let's play".
```

## Variação B — carinha

```
Four playing cards fanned out like a hand being shown, slightly tilted, their bottom corners
meeting at one point. From back to front the card faces are: sage green, cobalt blue, tomato red,
and the front card is cream. Each colored card has only a thin cream inner border and no symbols.
The front cream card shows a simple, big winking smiley face drawn in black ink (two dots, one of
them a wink, and a wide grin), with rosy cheeks. A tiny soft shadow under each card. Mood: playful,
cheeky, friends laughing around a table.
```

## Variação C — cartas voando

```
Four playing cards bursting upward out of a small fan, as if just thrown into the air in
celebration, each one slightly rotated and separated, with a few short black ink motion lines
around them. Card colors: sage green, cobalt blue, tomato red, and one cream card in front with a
chunky mustard-gold star with a thick black outline. Each colored card has a thin cream inner
border and no symbols. Mood: energetic, party, fun.
```
