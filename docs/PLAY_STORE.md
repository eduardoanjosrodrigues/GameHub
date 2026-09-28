# Ficha da Play Store

## Textos

**Nome do app** (até 30 caracteres): gamehub: Chapéu e mais

**Descrição curta** (até 80): O jogo do chapéu no celular: explique, resuma e faça mímica com a galera.

**Descrição completa:**

O gamehub junta joguinhos pra jogar junto. O primeiro é o Chapéu, aquele clássico de festa:

• Cada um escreve palavras em segredo (ou usa as listas prontas do app).
• Dois times, Azul e Vermelho, se revezam pra adivinhar o máximo em 60 segundos.
• Três rodadas com as mesmas palavras: primeiro descrevendo, depois com uma palavra só, e por fim só na mímica.

Jogue do seu jeito:
• Passa-e-joga: um celular só, passando de mão em mão.
• Pelo Wi-Fi: cada um no seu celular, entrando na sala por QR code ou código. Um tablet pode virar o tabuleiro no meio da mesa, com placar e cronômetro.

Sem anúncios, sem cadastro e sem internet: funciona na rede da sua casa ou no roteador do celular de alguém.

## Classificação e público

- Categoria: Jogos > Casual (ou Jogos de palavras).
- Público-alvo: 18 anos ou mais (só a faixa 18+), decidido em 2026-09-28.
- Segurança dos dados: nenhum dado coletado nem compartilhado.
- Anúncios: não.

## Imagens (em `design/store/`)

| Arquivo | Uso na ficha |
|---|---|
| `icon_512.png` | Ícone do app (512×512) |
| `feature_graphic_1024x500.png` | Imagem de destaque |
| `phone/*.png` | Capturas de celular (1080×1920) |
| `tablet/*.png` | Capturas de tablet de 7" e 10" (1600×2560) |

Pra gerar de novo as capturas depois de mudar o visual:

```bash
godot -- --tour=/tmp/telas --tour-size=1080x1920
```
