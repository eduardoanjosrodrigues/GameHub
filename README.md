# gamehub

Hub de joguinhos de festa pra Android, feito em Godot 4.7. O primeiro jogo é o **Chapéu**: cada um escreve palavras, tudo vai pro chapéu, e dois times tentam adivinhar em três rodadas (Descrever, Uma palavra, Mímica). Dá pra jogar num celular só (passa-e-joga) ou cada um no seu celular pelo Wi-Fi, com um tablet opcional de tabuleiro.

O plano da Fase 1, com todas as decisões, está em [docs/PLANO_FASE_1.md](docs/PLANO_FASE_1.md).

## Estrutura

| Pasta | O que tem |
|---|---|
| `app/` | Casca do hub: navegação, telas (início, configurações, histórico), componentes de interface, autoloads (`Settings`, `Audio`, `Haptics`, `History`, `App`) |
| `design/` | Tokens de cor e forma, fontes, tema, ícones SVG e imagens da loja |
| `net/` | Rede local genérica: transporte ENet (`Net`), descoberta por broadcast, código de sala, QR code, link de entrada |
| `games/chapeu/rules/` | Regras do Chapéu como máquina de estados pura (sem tela, sem rede) |
| `games/chapeu/session/` | Quem roda as regras: passa-e-joga, host no Wi-Fi e cliente no Wi-Fi |
| `games/chapeu/screens/` | Telas do Chapéu |
| `tests/` | Testes automáticos |
| `tools/` | Tour de capturas de tela, robôs de teste de rede, gerador de sons, build do Android |
| `android/build/` | Template Gradle do Godot com o filtro do link `gamehub://entrar` (QR) |

## Comandos

Use o executável do Godot 4.7.2 (aqui: `~/Downloads/Godot_v4.7.2-stable_linux.x86_64`, chamado de `godot` abaixo).

Rodar o app no PC:

```bash
godot --path .
```

Testes das regras, do código de sala e do QR:

```bash
godot --headless -s res://tests/run_tests.gd
```

Partida inteira pela rede com 4 robôs (inclui queda de conexão e alguém tentando entrar atrasado):

```bash
tools/net_test.sh godot
```

Capturas de todas as telas num tamanho exato:

```bash
godot -- --tour=/tmp/telas --tour-size=1080x1920
```

Gerar de novo os sons e músicas (sintetizados, sem arquivos de terceiros):

```bash
python3 tools/audio/generate_audio.py
```

Build do Android (detalhes em [docs/ANDROID.md](docs/ANDROID.md)):

```bash
tools/build_android.sh install
```
