# gamehub

Hub de joguinhos de festa pra Android, feito em Godot 4.7. O primeiro jogo é o **Chapéu**: cada um escreve palavras, tudo vai pro chapéu, e dois times tentam adivinhar em três rodadas (Descrever, Uma palavra, Mímica). Dá pra jogar num celular só (passa-e-joga) ou cada um no seu celular pelo Wi-Fi, com um tablet opcional de tabuleiro.

O segundo é o **Halli Galli**: cada um vira uma carta na sua vez e, quando a mesa tem exatamente 5 de uma fruta, quem bater o sino primeiro leva as cartas. Pelo Wi-Fi, cada celular deitado na mesa é a carta do seu dono (arrastar vira, toque duplo bate o sino), e o sino é decidido pelo instante do toque num relógio sincronizado com o host, não pela ordem de chegada na rede. Também dá pra jogar com um aparelho só no meio da mesa.

O terceiro é o **Avalon**, de papéis secretos (5 a 10 pessoas): cada celular mostra o papel e o que a pessoa sabe, os votos são secretos e revelados juntos, e as cartas de missão são embaralhadas. Um tablet, TV ou notebook pode ser o tabuleiro. Plano em [docs/PLANO_AVALON.md](docs/PLANO_AVALON.md); os prompts da arte estão em [docs/avalon_prompts.md](docs/avalon_prompts.md).

Os primeiros jogos solo são o **Wordle** (palavra do dia, treino, Dueto/Quarteto e Corrida no Wi-Fi) e o **Senha** (tipo Mastermind, com senha do dia, Duelo e Corrida). Plano em [docs/PLANO_WORDLE_SENHA.md](docs/PLANO_WORDLE_SENHA.md).

O plano da Fase 1, com todas as decisões, está em [docs/PLANO_FASE_1.md](docs/PLANO_FASE_1.md). O do Halli Galli está em [docs/PLANO_HALLI_GALLI.md](docs/PLANO_HALLI_GALLI.md).

## Estrutura

| Pasta | O que tem |
|---|---|
| `app/` | Casca do hub: navegação, telas (início, configurações, histórico), componentes de interface, autoloads (`Settings`, `Audio`, `Haptics`, `History`, `App`) |
| `design/` | Tokens de cor e forma, fontes, tema, ícones SVG e imagens da loja |
| `net/` | Rede local genérica: transporte ENet (`Net`), descoberta por broadcast, código de sala, QR code, link de entrada, relógio sincronizado (`ClockSync`), pergunta de qual jogo é a sala (`RoomProbe`) |
| `games/chapeu/rules/` | Regras do Chapéu como máquina de estados pura (sem tela, sem rede) |
| `games/chapeu/session/` | Quem roda as regras: passa-e-joga, host no Wi-Fi e cliente no Wi-Fi |
| `games/chapeu/screens/` | Telas do Chapéu |
| `games/avalon/` | Avalon: regras, sessões (host/cliente, jogador ou tabuleiro), telas, carta de papel e trilha de missões, arte |
| `games/halli_galli/` | Halli Galli: regras (`rules/`), sessões mesa/host/cliente (`session/`), telas, desenho das cartas e da mesa (`ui/`), arte e sons |
| `web/` | Página pra jogar pelo navegador (iPhone ou quem não tem o app): HTML/JS servido pelo celular do host, na rede local |
| `tests/` | Testes automáticos |
| `tools/` | Tour de capturas de tela, robôs de teste de rede, gerador de sons, build do Android |
| `android/build/` | Template Gradle do Godot com o filtro do link `gamehub://entrar` (QR) |

## Créditos

- Fontes: Fraunces e Manrope (SIL Open Font License), em `design/fonts/`.
- Ícones: [Phosphor Icons](https://phosphoricons.com) (MIT), em `design/icons/`.
- Palavras válidas do Wordle: [VERO](https://pt-br.libreoffice.org/projetos/projeto-vero-verificador-ortografico/), do LibreOffice (LGPLv3/MPL), em `games/wordle/data/palpites.txt`.
- Ilustrações, sons e músicas: feitos no próprio projeto.

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

Wordle e Senha pela rede (Corrida com queda de conexão, ou Duelo):

```bash
tools/desafio_net_test.sh wordle corrida pontos godot
tools/desafio_net_test.sh senha duelo tentativas godot
```

Justiça do sino do Halli Galli pela rede (4 robôs com atrasos diferentes; quem toca primeiro tem a pior rede e tem que ganhar todas):

```bash
tools/halli_net_test.sh godot
```

Partida inteira de Avalon pela rede (5 robôs jogadores + 1 tabuleiro, um cai e volta):

```bash
tools/avalon_net_test.sh godot
```

Partida inteira de Secret Hitler pela rede (7 robôs jogadores + 1 tabuleiro, um cai e volta):

```bash
tools/sh_net_test.sh godot
```

Partida inteira de Ito ou de Sintonia pela rede (5 robôs jogadores + 1 tabuleiro, um cai e volta; confere que ninguém vê número alheio nem o alvo antes da hora):

```bash
tools/party_net_test.sh ito godot
tools/party_net_test.sh sintonia godot
```

Trocar aparelho no meio da partida (a Eva some de vez, o tabuleiro abre o QR da vaga dela, um aparelho novo termina a partida no lugar dela e o antigo é recusado quando volta):

```bash
tools/avalon_swap_test.sh godot
```

Quem não tem o app entra pelo navegador: na sala, escolha o QR "Navegador (iPhone)" (a página fica em `http://IP-do-host:7780/`). Depois de mudar artes ou sons usados na página, copie de novo pra `web/assets/`:

```bash
tools/sync_web_assets.sh
```

Capturas de todas as telas num tamanho exato (`--tour-set=halli` só as do Halli Galli):

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
