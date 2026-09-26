# gamehub — Plano de implementação da Fase 1

> Status: rascunho v1 · 2026-09-25
> Escopo: app **gamehub** (hub de jogos para Android) + primeiro jogo completo, o **Chapéu**.

Legenda usada no documento:

- **[decidido]**: veio das suas respostas.
- **[proposta]**: sugestão minha, precisa do seu ok (está tudo listado em §13).
- **[verificar]**: fato técnico que precisa ser confirmado durante a implementação.

---

## 1. Visão geral

O gamehub é um app mobile com vários joguinhos de festa: alguns single player, outros multiplayer por Wi-Fi local. A Fase 1 entrega:

1. A casca do hub: tela de jogos, configurações e histórico.
2. O Chapéu completo, em dois modos: **passa-e-joga** (um aparelho) e **Wi-Fi** (cada um no seu celular, com tablet opcional como tabuleiro).
3. A publicação na Play Store.

### O que NÃO entra na Fase 1 [decidido]

- iOS.
- Perfil de jogador salvo (só o último nome digitado é lembrado).
- Anúncios e compras no app.
- Outros idiomas além do pt-BR.
- Tema escuro.
- Paisagem (o app inteiro é em retrato).

---

## 2. Decisões consolidadas

| Área | Decisão |
|---|---|
| Engine | Godot 4.7.2 (GDScript) |
| Plataforma | Só Android, **Android 12+** (API 31) |
| Orientação | Retrato em todos os aparelhos |
| Idioma | Só pt-BR |
| Estilo visual | Cartoon colorido: formas arredondadas, contorno grosso, sombra dura |
| Paleta | Vibrante fria (azul, turquesa, verde-limão, rosa, fundo gelo), usada no hub e no Chapéu |
| Identidade por jogo | Cada jogo futuro terá visual próprio; na Fase 1 hub e Chapéu compartilham a paleta |
| Tema | Só claro |
| Artes | Todas em vetor (SVG), geradas dentro do projeto |
| Avatar | Círculo com a cor + inicial do nome |
| Nome | Digitado por partida; o aparelho lembra o último usado |
| Som | Efeitos sonoros + música de fundo + vibração |
| Hub | Tela de jogos, Configurações, Histórico |
| Publicação | Play Store (sem monetização) |

### Regras do Chapéu [decidido]

| Regra | Valor |
|---|---|
| Rodadas | 3, nesta ordem: **Descrever** → **Uma palavra** → **Mímica** |
| Times | 2 times fixos, **Time Azul** (Time 1) e **Time Vermelho** (Time 2), 4 a 12 jogadores |
| Montagem dos times | Cada jogador escolhe o próprio time (no lobby, ou na tela de jogadores do passa-e-joga) |
| Quem começa | Sempre o Time Azul |
| Tempo por vez | 60 segundos (fixo) |
| Pular | Pode; custa **−1 ponto**; a palavra volta pro chapéu |
| Pontuação negativa | Pode |
| Fonte das palavras | Host escolhe: só jogadores, só lista pronta, ou mistura |
| Mistura | Quantidade fixa: X palavras por jogador + Y da lista pronta |
| Palavras por jogador | Configurável pelo host |
| Listas prontas | Poucas e gerais (2 a 3 temas) |
| Quem explica | O time escolhe na hora, a cada vez |
| Quem confirma o acerto | Quem está explicando (botões na própria tela) |
| Chapéu esvazia no meio da vez | O mesmo jogador continua na próxima rodada com o tempo que sobrou |
| Pausa | Quem está explicando pode pausar |
| Desempate | 1º mais pontos totais → 2º mais rodadas vencidas → 3º mais pontos na rodada de mímica |
| Palavras duplicadas | Permitidas: se dois jogadores escrevem a mesma, as duas vão pro chapéu |
| Time adversário vê a palavra (Wi-Fi) | Configurável pelo host, padrão **não** |
| Corrigir toque errado | Não dá: o que foi apertado vale |

### Multiplayer [decidido]

| Tema | Decisão |
|---|---|
| Modos | Passa-e-joga **e** Wi-Fi |
| Tablet | Pode entrar como **tabuleiro** (placar e timer, sem ser jogador) |
| Host | O tabuleiro, se existir; senão, quem criou a sala |
| Entrar na sala | Descoberta automática + QR code + código/IP |
| Queda de conexão | O jogador reconecta e volta pro mesmo lugar; se era a vez dele, o jogo pausa |
| Entrar atrasado | Não pode: depois que a partida começa, só entra quem já estava nela (reconexão) |
| Palavras no passa-e-joga | O aparelho passa de mão em mão; cada um digita as suas com a tela escondida |

---

## 3. Especificação das regras do Chapéu

### 3.1 Configuração da partida (feita pelo host)

- **Fonte das palavras**: `jogadores` | `lista` | `mistura`.
- **Palavras por jogador** (se `jogadores` ou `mistura`): de 1 a 10, padrão **4** [proposta].
- **Quantidade da lista** (se `lista` ou `mistura`): de 10 a 100, padrão **30** [proposta].
- **Temas da lista** (se `lista` ou `mistura`): um ou mais temas marcados.
- **Time adversário vê a palavra** (só Wi-Fi): liga/desliga, padrão desligado.
- Tempo (60 s), penalidade de pulo (−1) e rodadas são fixos, não aparecem como opção.

### 3.2 Fluxo da partida

```
Configuração → Jogadores escolhem o time → Escrever palavras
  → [Rodada 1: Descrever] → [Rodada 2: Uma palavra] → [Rodada 3: Mímica]
  → Resultado final
```

Cada rodada:

1. **Abertura da rodada**: tela com a regra ("Explique sem dizer a palavra", etc.) e o placar.
2. Todas as palavras voltam pro chapéu, embaralhadas.
3. **Vezes** se alternam entre os times: A, B, A, B...
4. Na **preparação da vez**: "Vez do Time Azul. Quem vai explicar?" O time toca no nome de quem vai.
5. **Vez**: o cronômetro começa quando o explicador toca em "Começar".
   - Aparece uma palavra sorteada do chapéu.
   - **Acertou**: +1 pro time, a palavra sai do chapéu, aparece a próxima.
   - **Pular**: −1 pro time, a palavra volta pro chapéu (não pode ser a próxima sorteada, a não ser que seja a única), aparece outra.
   - **Pausar**: congela o cronômetro e esconde a palavra.
6. **Fim da vez** (tempo zerou): a palavra na tela volta pro chapéu. Aparece o **resumo da vez** (acertos, pulos, saldo).
7. **Fim da rodada** (chapéu vazio):
   - Se aconteceu no meio de uma vez, o tempo restante do explicador fica guardado. Na próxima rodada, **o mesmo jogador começa** com esse tempo (pula a preparação da vez).
   - Se era a última rodada, a partida acaba.
   - Tela de placar da rodada: pontos da rodada por time e total acumulado.

- A partida só começa com **pelo menos 2 jogadores em cada time** (um explica, pelo menos um adivinha).
- **Quem começa**: sempre o Time Azul. Nas rodadas seguintes, a alternância continua de onde parou (a não ser que alguém tenha tempo guardado, que aí começa).
- **Dentro do time**, quem explica é escolhido na hora; o app mostra quantas vezes cada um já explicou, pra ajudar a revezar [proposta].

### 3.3 Pontuação e vencedor

- Pontos por rodada = acertos − pulos (pode ser negativo).
- **Vencedor da rodada** = time com mais pontos naquela rodada (empate na rodada: ninguém vence a rodada) [proposta].
- **Vencedor da partida**, em ordem:
  1. Mais pontos totais.
  2. Mais rodadas vencidas.
  3. Mais pontos na rodada de Mímica.
  4. Se ainda empatar: ver pendência P2.

### 3.4 Palavras

- As palavras são normalizadas pra comparação (minúsculas, sem acento, sem espaço sobrando). A comparação só serve pra mistura (abaixo); na tela, a palavra aparece como foi digitada.
- Duplicadas são permitidas: se dois jogadores escrevem "Pelé", entram dois papéis com "Pelé".
- Tamanho máximo: 40 caracteres [proposta].
- No modo `mistura`, as palavras da lista são sorteadas sem repetir palavras que os jogadores já escreveram.

### 3.5 Listas prontas [proposta]

Três temas gerais, ~150 palavras cada, em pt-BR:

- **Pessoas famosas** (brasileiras e internacionais, reais e personagens).
- **Coisas e lugares** (objetos, comidas, animais, lugares).
- **Filmes, séries e músicas**.

Formato: `res://games/chapeu/words/<tema>.json`, com `{ "id", "nome", "palavras": [...] }`. Você revisa as listas antes de fechar.

---

## 4. Modos de jogo

### 4.1 Passa-e-joga

- Um aparelho só. As telas são as mesmas do fluxo acima.
- **Escrever palavras**: uma tela por jogador, "Passe para **Ana**" → Ana digita as suas → "Pronto, esconder" → próximo jogador. Uma palavra digitada nunca reaparece na tela depois de confirmada.
- **Na vez**, o aparelho fica com o explicador, que vê a palavra e aperta Acertou/Pular.

### 4.2 Wi-Fi

Papéis de aparelho:

| Papel | O que vê |
|---|---|
| **Tabuleiro** (opcional, geralmente tablet) | Placar, rodada atual, regra da rodada, cronômetro grande, de quem é a vez, código/QR da sala durante o lobby |
| **Explicador** (jogador da vez) | A palavra, Acertou / Pular / Pausar, cronômetro |
| **Time da vez** | "Adivinhe!", cronômetro, nome de quem explica |
| **Outro time** | Cronômetro e "Vez do time X". Se o host ligou a opção, também vê a palavra (pra fiscalizar) |
| **Host** | O tabuleiro, se existir; senão o celular de quem criou a sala, que também joga |

- **Escrever palavras**: cada um no próprio celular, ao mesmo tempo. O host vê quem já terminou.
- **Escolher explicador**: qualquer um do time da vez toca no nome; o primeiro toque vale.
- **Times**: no lobby, cada jogador toca em "Time Azul" ou "Time Vermelho" e pode trocar até o host iniciar.
- **Configuração**: só o host mexe; os outros acompanham ao vivo.
- **Entrar atrasado**: depois que a partida começa, a sala some da descoberta e o host recusa aparelhos novos. Só aceita quem já estava na partida (mesmo `device_id`).

---

## 5. Arquitetura técnica

### 5.1 Princípio: regras separadas de tela e de rede

```
┌──────────────┐   ações    ┌───────────────────┐   eventos/estado   ┌───────────┐
│  Tela (UI)   │ ─────────▶ │  ChapeuRules      │ ─────────────────▶ │ Tela (UI) │
└──────────────┘            │  (GDScript puro,  │                    └───────────┘
                            │   sem nós, sem    │
                            │   rede, testável) │
                            └───────────────────┘
       Passa-e-joga: UI → regras locais
       Wi-Fi:        UI → rede → regras no host → rede → UI de todos
```

- `ChapeuRules` é um `RefCounted` com o **estado** (dicionário serializável) e `apply(action) -> Array[Event]`.
- É determinística: recebe uma semente de aleatoriedade, então qualquer partida pode ser reproduzida em teste.
- O **host é autoritativo**: só ele roda as regras; os clientes mandam **intenções** (ex: `{type: "acertou"}`) e recebem estado + eventos.
- O cronômetro faz parte das regras (tempo restante em ms), avançado pelo `tick(delta)` do host.

### 5.2 Estrutura de pastas

```
res://
├── app/                    # casca do hub
│   ├── autoload/           # App, Settings, Audio, Haptics, History, Net
│   ├── screens/            # hub, configuracoes, historico
│   └── ui/                 # componentes compartilhados (botão, card, avatar, modal...)
├── design/
│   ├── theme.tres          # Theme do Godot com a paleta e fontes
│   ├── tokens.gd           # cores, espaçamentos, raios (constantes)
│   ├── fonts/
│   └── icons/              # SVGs
├── net/                    # lobby, descoberta, protocolo, reconexão (reutilizável por outros jogos)
├── games/
│   └── chapeu/
│       ├── rules/          # ChapeuRules + tipos (sem dependência de nós)
│       ├── screens/
│       ├── words/          # listas JSON
│       └── audio/
└── tests/                  # testes das regras e do protocolo
```

### 5.3 Autoloads

| Autoload | Responsabilidade |
|---|---|
| `App` | Navegação entre telas, transições, botão voltar do Android |
| `Settings` | Volume da música, volume dos efeitos, vibração on/off, último nome; salvo em `user://settings.cfg` |
| `Audio` | Música com crossfade entre telas; efeitos com pool de players |
| `Haptics` | `Input.vibrate_handheld()` respeitando a configuração |
| `History` | Salva partidas em `user://history.json` |
| `Net` | Criar/entrar em sala, descoberta, envio de mensagens, reconexão |

### 5.4 Configurações do projeto Godot

- **Renderer**: Compatibility (OpenGL), leve e suficiente pra 2D [proposta].
- **Resolução base**: 720×1280, `stretch/mode = canvas_items`, `stretch/aspect = expand`.
- **Orientação**: `portrait`.
- **Safe area**: todas as telas ficam dentro de `DisplayServer.get_display_safe_area()` (câmera/notch, barra de gestos).
- **Tablet**: acima de 600 dp de largura, o conteúdo fica centralizado com largura máxima (~560 px na base), e o tabuleiro usa um layout próprio com cronômetro e placar grandes.
- **Botão voltar do Android**: tratado em `App` (`NOTIFICATION_WM_GO_BACK_REQUEST`); durante a partida, pede confirmação antes de sair.

---

## 6. Rede (Wi-Fi local)

### 6.1 Transporte

- `ENetMultiplayerPeer` (UDP confiável), porta **7777** [proposta].
- Todas as mensagens passam por **um único par de RPCs** (`client_to_host(msg)` e `host_to_clients(msg)`), com `msg` sendo um dicionário `{v, type, ...}`. Isso mantém o protocolo simples de versionar e testar sem depender de nós.
- `v` = versão do protocolo. Aparelhos com versão diferente recebem "Atualize o app" ao entrar.

### 6.2 Formas de entrar na sala

1. **Descoberta automática**: o host transmite um sinal UDP broadcast na porta **7778** a cada 1 s com `{app: "gamehub", jogo: "chapeu", nome_sala, porta, jogadores, v}`. Quem abre "Entrar" escuta e lista as salas.
   - Exige a permissão `CHANGE_WIFI_MULTICAST_STATE` no export do Android.
2. **QR code**: o host mostra um QR com `gamehub://entrar?ip=<ip>&porta=<porta>&sala=<código>`.
   - Gerar o QR: codificador em GDScript dentro do projeto [verificar se já há algo nativo no 4.7].
   - Ler o QR: precisa de câmera + decodificador. **Risco técnico** (ver §11): provavelmente via plugin Android (ex: ZXing / ML Kit) [verificar].
3. **Código / IP**: o host mostra um código curto de 6 caracteres que codifica o IP e a porta (e o IP por extenso, como último recurso). O cliente digita o código.

### 6.3 Identidade e reconexão

- Cada aparelho gera um `device_id` (UUID) na primeira execução, salvo em `user://`.
- Ao entrar, o cliente manda `{type: "hello", device_id, nome, papel}`. O host associa `device_id → jogador`.
- Se a conexão cair: o jogador fica marcado "desconectado", mantendo lugar, time e pontos. O cliente tenta reconectar sozinho (a cada 2 s, até 60 s) [proposta]. Ao voltar com o mesmo `device_id`, recebe o estado completo.
- **Se o explicador cair**: o jogo pausa automaticamente e todos veem "Esperando **Ana** voltar...". O host pode escolher outro explicador do mesmo time ou continuar esperando [proposta].
- **Se o host cair**: a partida fica "Esperando o host". Migração de host não entra na Fase 1 [proposta].

### 6.4 Sincronização

- Após cada ação, o host manda o **estado completo** (é pequeno, bem menos de 10 KB) + os eventos (pra tocar som/animação).
- **Palavras não vão pra todo mundo**: o estado enviado a cada cliente é filtrado pelo papel dele (o chapéu fica só no host; a palavra atual só vai pra quem pode vê-la).
- Cronômetro: o host manda o tempo restante a cada 250 ms; os clientes interpolam localmente.

### 6.5 Mensagens do protocolo (primeira versão)

| Direção | Tipo | Conteúdo |
|---|---|---|
| C→H | `hello` | device_id, nome, papel (`jogador`/`tabuleiro`) |
| C→H | `escolher_time` | `azul` / `vermelho` (só no lobby) |
| C→H | `palavras` | lista de palavras do jogador |
| C→H | `escolher_explicador` | player_id |
| C→H | `comecar_vez` / `acertou` / `pular` / `pausar` / `retomar` | — |
| C→H (host local) | `config`, `iniciar` | parâmetros |
| H→C | `bem_vindo` | player_id, estado completo |
| H→C | `estado` | estado filtrado + eventos |
| H→C | `tempo` | ms restantes |
| H→C | `erro` | código + mensagem (ex: `partida_em_andamento` pra quem tenta entrar atrasado) |

---

## 7. Design system

### 7.1 Paleta [decidido a direção; tons de apoio são proposta]

| Token | Hex | Uso |
|---|---|---|
| `azul` | `#3A86FF` | Cor primária, botões principais, **Time Azul** |
| `vermelho` | `#FF3B4E` | **Time Vermelho** [proposta de tom] |
| `rosa` | `#FF4D8D` | Destaque, pular/penalidade |
| `turquesa` | `#06D6A0` | Sucesso, "Acertou!" |
| `lima` | `#C6F432` | Brilho e realce (cronômetro, confete, badges) |
| `gelo` | `#F4F7FF` | Fundo das telas |
| `branco` | `#FFFFFF` | Cards e superfícies |
| `tinta` | `#1B1F3B` | Texto, contornos e sombras duras |
| `tinta-suave` | `#5A6080` | Texto secundário |
| `azul-escuro` | `#1F5FCC` | Detalhes do azul (faixas, anel do cronômetro, sombra interna); nunca atrás de texto |
| `vermelho-escuro` | `#D42637` | Detalhes do vermelho; nunca atrás de texto |
| `rosa-escuro` | `#D93672` | Detalhes do rosa; nunca atrás de texto |
| `turquesa-escuro` | `#04A77D` | Detalhes do turquesa; nunca atrás de texto |

**Regra de contraste** (conferida por script, padrão WCAG): texto sobre `azul`, `vermelho`, `rosa`, `turquesa`, `lima`, `gelo` e `branco` usa **`tinta`** (4.6:1 a 16:1). Texto branco só em títulos grandes (≥ 24 px, negrito) sobre `azul`, `vermelho` ou `rosa` (3.1:1 a 3.5:1, aceitável só pra texto grande). Os tons `-escuro` do azul, vermelho e rosa ficam entre 2.7:1 e 3.6:1 com `tinta`, por isso **o botão pressionado mantém a cor** e só desce 4 px (§7.3).

**Times**: Time Azul e Time Vermelho. Os avatares dos jogadores usam a cor do time. O vermelho não faz parte da paleta fria original; entrou só como cor de time.

### 7.2 Tipografia [proposta]

- **Títulos e botões**: *Fredoka* (arredondada, cara de cartoon), SemiBold/Bold.
- **Texto**: *Nunito*, Regular/Bold.
- Ambas com licença OFL, embutidas no projeto (funcionam offline).
- Escala (px na resolução base): 56 palavra da vez · 40 título · 28 subtítulo · 22 botão · 18 texto · 14 legenda.

### 7.3 Forma e profundidade

- Contorno `tinta` de **3 px** em botões, cards e avatares.
- Sombra dura: deslocada 0, +6 px, cor `tinta`, sem desfoque. Ao pressionar, o botão desce 4 px e a sombra encolhe (efeito de "apertar").
- Raio dos cantos: 20 px em cards, 999 px (pílula) em botões.
- Espaçamento em múltiplos de 8 px.
- Área mínima de toque: 56 px de altura.

### 7.4 Componentes

| Componente | Descrição |
|---|---|
| `BotaoCartoon` | Primário (azul), secundário (branco), sucesso (turquesa), perigo (rosa); com som e vibração leve ao tocar |
| `CardJogo` | Card do hub com ilustração, nome e estado ("Jogar" / "Em breve") |
| `Avatar` | Círculo com a cor do time + inicial; indicador de desconectado |
| `Cronometro` | Anel que esvazia; fica `rosa` e pulsa nos últimos 10 s |
| `Placar` | Os dois times lado a lado com os pontos |
| `CartaPalavra` | Carta grande com a palavra; anima entrando e saindo (acertou: voa pra cima; pulou: volta pro chapéu) |
| `Modal` | Confirmações (sair da partida etc.) |
| `Toast` | Avisos curtos ("Ana entrou", "Reconectando...") |
| `CampoTexto` | Input no estilo cartoon, com o teclado do Android |

### 7.5 Animação

- Transições entre telas: deslizar + leve "quique" (Tween com `TRANS_BACK`), 250 ms.
- Botões: escala 0.95 ao pressionar.
- Acertou: confete `lima`/`turquesa`/`azul`/`rosa`.
- Fim da partida: chapéu pulando + confete com a cor do time vencedor.

### 7.6 Artes (todas em SVG, geradas no projeto) [decidido]

- Ícone do app (formato adaptativo do Android: frente + fundo).
- Logo "gamehub".
- Ilustração do Chapéu (chapéu cartoon com papeizinhos saindo).
- Ícones: jogar, configurações, histórico, voltar, pausar, pular, check, wifi, QR, tablet, pessoa, troféu.
- Ilustração das 3 rodadas (boca falando, "1", mãos de mímica).
- Placeholder "Em breve" pros próximos jogos.

---

## 8. Telas

### 8.1 Hub

| Tela | Conteúdo |
|---|---|
| **Splash** | Logo animado (≤ 1,5 s) |
| **Início** | Logo, grade de jogos (Chapéu + cards "Em breve"), botões Histórico e Configurações |
| **Configurações** | Volume da música, volume dos efeitos, vibração on/off, versão do app, link da política de privacidade |
| **Histórico** | Lista das partidas: data, jogo, modo, times com jogadores, placar, vencedor. Toque abre o detalhe (pontos por rodada) |

### 8.2 Chapéu

| # | Tela | Passa-e-joga | Wi-Fi |
|---|---|---|---|
| 1 | Menu do Chapéu: **Passa-e-joga**, **Criar sala**, **Entrar**, **Como jogar** | ✓ | ✓ |
| 2 | Como jogar (regras ilustradas em 3 cartões) | ✓ | ✓ |
| 3 | Criar sala: "Vou jogar" ou "Este aparelho é o tabuleiro" | — | ✓ |
| 4 | Entrar: salas encontradas + "Ler QR" + "Digitar código" | — | ✓ |
| 5 | Seu nome (pré-preenchido com o último) | ✓ (um por jogador) | ✓ |
| 6 | Lobby: código + QR da sala, duas colunas (Time Azul / Time Vermelho), cada jogador toca no time que quer | — | ✓ |
| 7 | Jogadores: adicionar/remover nomes, cada um já no seu time (tocar no nome troca de time) | ✓ | — |
| 8 | Configuração (fonte das palavras, quantidades, temas, adversário vê a palavra) | ✓ | ✓ (host edita) |
| 9 | *(removida: os times são montados nas telas 6 e 7)* | — | — |
| 10 | Escrever palavras ("Passe para X" / no próprio celular) | ✓ | ✓ |
| 11 | Abertura da rodada (regra + placar) | ✓ | ✓ |
| 12 | Preparação da vez ("Quem vai explicar?") | ✓ | ✓ |
| 13 | Vez: explicador (palavra, Acertou, Pular, Pausar) | ✓ | ✓ |
| 14 | Vez: quem adivinha / outro time | — | ✓ |
| 15 | Resumo da vez (só leitura, sem corrigir) | ✓ | ✓ |
| 16 | Placar da rodada | ✓ | ✓ |
| 17 | Resultado final (vencedor, critério de desempate usado, pontos por rodada, "Jogar de novo" com os mesmos times) | ✓ | ✓ |
| 18 | Tabuleiro (layout próprio acompanhando todas as fases) | — | ✓ |
| 19 | Pausa / esperando reconexão | ✓ | ✓ |

---

## 9. Som e vibração

### 9.1 Efeitos

Tocar botão · acertou · pular · palavra nova · tique nos últimos 10 s · tempo esgotado (buzina) · fim de rodada · vitória · jogador entrou/saiu.

### 9.2 Música

- Trilha do hub/menus (animada, em loop).
- Trilha durante a vez (mais tensa; acelera nos últimos 10 s) [proposta].
- Silêncio na tela de escrever palavras [proposta].

### 9.3 Origem dos áudios

Eu produzo o básico dentro do projeto:

- **Efeitos**: sintetizados por um script (ondas simples + envelopes, no estilo sfxr), gerando `.wav` em `res://app/audio/sfx/` e `res://games/chapeu/audio/`.
- **Músicas**: loops curtos compostos por script (melodia + baixo + bateria sintetizados), exportados em `.ogg`.
- O script fica em `tools/audio/`, pra dar pra ajustar e gerar de novo. Se depois você quiser trocar por áudio profissional, é só substituir os arquivos.

### 9.4 Vibração

- Toque leve em botões principais (20 ms).
- Acertou (40 ms), pular (2× 30 ms).
- Pulso a cada segundo nos últimos 5 s, e vibração longa no fim do tempo (400 ms).
- Permissão `VIBRATE` no export.

---

## 10. Android e Play Store

### 10.1 Build

- `minSdk` **31** (Android 12). `targetSdk`: o exigido pela Play Store na data de publicação [verificar].
- Arquitetura: `arm64-v8a` (+ `armeabi-v7a` se aparecer aparelho de teste que precise) [proposta].
- Formato: **AAB** pra loja, APK pra testes.
- Permissões: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, `VIBRATE`, `CAMERA` (QR, pedida só quando tocar em "Ler QR").
- **Rede local nas versões novas do Android**: o Android vem restringindo acesso à rede local (proteção de rede local). Verificar se o `targetSdk` exigido obriga pedir permissão específica pra falar com aparelhos da mesma rede [verificar].
- Ambiente: instalar Android SDK (command-line tools, platform-tools, build-tools, platform), templates de export do Godot 4.7.2, e confirmar qual versão de JDK o 4.7.2 exige (tem JDK 21 instalado) [verificar].
- Keystore de upload guardada fora do repositório, com backup.

### 10.2 Publicação

1. Conta de desenvolvedor Google Play (taxa única de US$ 25).
2. **Contas pessoais novas precisam de teste fechado com pelo menos 12 testadores por 14 dias seguidos** antes de liberar a produção [verificar regra atual]. Precisa de 12 pessoas com Android dispostas a instalar.
3. Play App Signing ativado.
4. Ficha da loja: nome, descrição curta/longa em pt-BR, ícone 512×512, imagem de destaque 1024×500, capturas de celular e de tablet (7" e 10").
5. Política de privacidade: texto em [politica-de-privacidade.md](politica-de-privacidade.md). A loja exige uma URL pública; a hospedagem fica pra depois.
6. Formulário de Segurança dos dados: "nenhum dado coletado ou compartilhado".
7. Classificação indicativa (questionário IARC).
8. Público-alvo: **13 anos ou mais** (faixas 13–15, 16–17 e 18+), escolhido por mim a seu pedido. Motivo: incluir menores de 13 coloca o app nas regras de "Famílias" da Play Store, com exigências extras. E como os jogadores digitam as próprias palavras, não dá pra garantir que o conteúdo seja adequado pra crianças.

---

## 11. Riscos técnicos

| Risco | Impacto | Mitigação |
|---|---|---|
| Leitura de QR precisa de câmera + decodificador | Pode exigir plugin Android nativo | Fazer por último entre as formas de entrar; descoberta automática e código já cobrem o básico |
| Roteadores com isolamento de clientes (Wi-Fi de hotel, empresa, alguns de operadora) | Aparelhos não se enxergam | Mensagem clara na tela "Entrar" sugerindo usar o roteador do celular do host |
| Broadcast UDP filtrado por alguns aparelhos | Descoberta automática falha | Código/IP e QR como alternativa, sempre visíveis |
| Mudanças de permissão de rede local no Android | Conexão bloqueada no Android mais novo | Verificar no início do M5 (§12) e testar num aparelho com Android recente |
| Teclado do Android cobrindo campos | Tela de escrever palavras fica ruim | Mover o conteúdo com base na altura do teclado (`DisplayServer.virtual_keyboard_get_height()`) |
| Exigência de 12 testadores por 14 dias | Atrasa a publicação | Recrutar testadores cedo (durante o M8) |
| Só um celular e nenhum tablet pra testar | Bugs de rede entre aparelhos e de layout de tablet aparecem tarde | Usar instâncias no desktop + emulador Android (celular e tablet); fazer um playtest com os celulares da galera logo no fim do M5, não só no M8 |

---

## 12. Marcos

Cada marco termina com algo que dá pra instalar e testar no celular.

| Marco | Entrega | Critério de pronto |
|---|---|---|
| **M0 — Ambiente** | Projeto Godot, git, Android SDK, export funcionando | APK "hello world" rodando num celular Android 12+ |
| **M1 — Design system** | Tema, tokens, fontes, componentes, ícones SVG, tela de amostra de componentes | Todos os componentes da §7.4 renderizados no celular e no tablet |
| **M2 — Casca do hub** | Splash, Início, Configurações, Histórico (vazio), navegação, voltar do Android, `Settings`, `Audio`, `Haptics` | Configurações persistem após fechar o app |
| **M3 — Regras do Chapéu** | `ChapeuRules` + testes automatizados | Testes cobrindo: pulo com penalidade, tempo esgotado, chapéu esvaziando no meio da vez (tempo passa pra próxima rodada), os 3 critérios de desempate, fontes de palavras, duplicadas entrando duas vezes, mínimo de 2 por time, Time Azul começando |
| **M4 — Passa-e-joga** | Telas 1, 2, 5, 7, 8, 10–13, 15–17, 19 | Partida completa com 4 pessoas reais num aparelho |
| **M5 — Rede básica** | Criar sala, entrar por IP/código, lobby com escolha de time, protocolo, estado filtrado | Partida completa: seu celular + 3 instâncias no PC na mesma rede; depois um playtest com celulares da galera |
| **M6 — Descoberta e QR** | Broadcast + lista de salas + QR (gerar e ler) | Entrar pelos 3 caminhos (celular ↔ PC, e celular ↔ emulador) |
| **M7 — Tabuleiro e reconexão** | Papel tabuleiro, tela 18, reconexão, pausa ao cair, recusar quem entra atrasado | Derrubar o Wi-Fi do celular no meio da vez e ele voltar pro mesmo lugar; tabuleiro conferido no emulador de tablet |
| **M8 — Polimento** | Som, música, vibração, animações, listas de palavras revisadas, histórico gravando | Playtest com o grupo; lista de ajustes resolvida |
| **M9 — Play Store** | Ícone, capturas, política, AAB assinado, teste fechado → produção | App aprovado e disponível na loja |

### Testes

- **Regras**: testes unitários (framework a definir no M0: GUT ou gdUnit4 [proposta]), usando semente fixa.
- **Rede**: rodar várias instâncias no desktop (Godot: Debug → Customize Run Instances) simulando host, jogadores e tabuleiro.
- **Aparelhos reais**: só o seu celular. Modelo e versão do Android são lidos via `adb` no M0 (precisa ser Android 12+).
- **Tablet**: emulador Android com perfil de tablet (10") e janela do desktop redimensionada.

---

## 13. Pendências (preciso da sua resposta)

| # | Pergunta |
|---|---|
| **P2** | Empate nos três critérios ao mesmo tempo (mesmos pontos totais, mesmo número de rodadas vencidas e mesmos pontos na mímica): declarar empate, ou outra regra? |
| **P12** | Política de privacidade (fica pra depois, antes do M9): onde hospedar, e preencher nome do desenvolvedor, e-mail de contato e data em [politica-de-privacidade.md](politica-de-privacidade.md). |
| **P11** | Revisar todas as **[proposta]** do documento: padrões de palavras (4 por jogador, 30 da lista), temas das listas, fontes Fredoka + Nunito, tons de apoio da paleta, tom do vermelho do time (`#FF3B4E`), contador de quantas vezes cada um explicou, renderer Compatibility, portas 7777/7778, reconexão por até 60 s, sem migração de host, música durante a vez, arquiteturas do build, framework de testes, vencedor de rodada empatada. |
