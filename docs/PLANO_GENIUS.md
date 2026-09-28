# gamehub — Plano do Genius

> Status: v1 · 2026-09-28 · implementado (§12), ainda não testado num celular de verdade nem com gente
> Escopo: o **Genius**, o jogo de memória das 4 cores: o aparelho toca uma sequência de luzes e sons e você repete. A cada acerto, a sequência ganha mais uma cor. Tem **solo**, **Passa o aparelho** (várias pessoas num aparelho) e **Corrida no Wi-Fi** (app ou navegador).

Legenda (a mesma dos outros planos): **[decidido]** veio das suas respostas; **[proposta]** é sugestão minha (lista em §9); **[verificar]** precisa ser confirmado.

---

## 1. Decisões [decidido]

| Área | Decisão |
|---|---|
| Nome | **Genius** (mesmo risco de marca do Halli Galli e do Wordle, pendência P1) |
| Modos | **Solo clássico**, **Passa o aparelho** e **Corrida no Wi-Fi**. Sem desafio do dia |
| Tabuleiro | **Só 4 cores**, no círculo clássico: verde, vermelho, amarelo e azul |
| Erro | Errou uma cor, **acabou** (sem vidas) |
| Velocidade | **Acelera como o original**, em degraus conforme a sequência cresce |
| Tempo para apertar | **Sem limite**: dá para pensar o quanto quiser |
| Som | **Os tons do Genius original**, uma nota por cor, gerados pelo app |
| Passa o aparelho | **O app cria** a sequência. Cada vez que alguém acerta, ela ganha uma cor para o **próximo** jogador. Todo mundo pode assistir |
| Corrida | **Rodadas juntas**: a cada rodada todos recebem a sequência ao mesmo tempo e respondem. Quem erra sai. A rodada **espera todo mundo** terminar, sem limite |
| Corrida: todos erram | Se todos os que restam errarem na mesma rodada, **ninguém sai** e a rodada se repete |
| Corrida: andamento | Durante a rodada, cada um vê **só o próprio tabuleiro**. No fim da rodada aparece quem passou e quem saiu |
| Corrida: navegador | **Sim**, entra pelo QR code, com luz e som no navegador |
| Recordes | **Só o recorde solo** (a maior sequência). As partidas com amigos vão para o **Histórico** do app |

## 2. Regras comuns

- A sequência é sorteada uma cor por vez, qualquer uma das 4, e **pode repetir** a mesma cor seguida (como no original) [proposta].
- Uma rodada: o aparelho **toca** a sequência inteira (cada cor acende e soa), depois o jogador **repete** tocando os botões. Durante a reprodução, os botões não respondem.
- Cada toque do jogador acende o botão e toca a nota dele, **enquanto o dedo estiver apertado** (como o original), com um mínimo de 0,15 s [proposta].
- Acertou a sequência inteira → pausa curta (~1,3 s [proposta]) e a próxima rodada começa com uma cor a mais.
- Errou → som de erro (o "buzz" grave do original), o botão certo **pisca** para mostrar qual era [proposta], e a partida acaba.
- O placar de uma partida é o **número de cores da maior sequência completada**.

### 2.1 Velocidade [decidido: como o original]

Valores do Simon original [verificar: medir de novo em vídeo do aparelho]:

| Tamanho da sequência | Cada cor acesa | Intervalo entre cores |
|---|---|---|
| 1 a 5 | 0,42 s | 0,05 s |
| 6 a 13 | 0,32 s | 0,05 s |
| 14 a 31 | 0,22 s | 0,05 s |
| 32 em diante | 0,22 s (não acelera mais) [proposta] | 0,05 s |

- O original "vencia" em 31 cores. Aqui a sequência **não tem fim**: segue até alguém errar [proposta]. Quando alguém passa de 31, aparece uma comemoração, sem parar o jogo [proposta].

### 2.2 Som [decidido: tons originais]

Notas do Simon original [verificar]:

| Cor | Frequência |
|---|---|
| Verde | 415 Hz (Sol♯ 4) |
| Vermelho | 310 Hz (Ré♯ 4) |
| Amarelo | 252 Hz (Si 3) |
| Azul | 209 Hz (Sol♯ 3) |
| Erro | 42 Hz, 1,5 s |

- Os sons são **gerados no próprio app** (onda quadrada suavizada, `AudioStreamGenerator`), sem arquivos, para a nota durar exatamente o tempo do toque [proposta]. No navegador, a mesma coisa com Web Audio.
- O volume segue o volume de efeitos das Configurações. Com o som desligado, o jogo continua só com a luz.

## 3. Solo clássico

- Menu do jogo: **Jogar** · Passa o aparelho · Jogar no Wi-Fi · Como jogar, com o **recorde** mostrado no topo.
- Na partida: o tabuleiro no centro, o placar atual e o recorde. No fim, "Você chegou a **N** cores", com "Novo recorde!" quando for o caso, e os botões **Jogar de novo** e **Menu**.
- Sair no meio da partida **descarta** a partida (sem continuar depois) [proposta].
- O recorde fica em `user://` junto das outras configurações do jogo.

## 4. Passa o aparelho [decidido: o app cria, cresce a cada vez]

1. Cadastro dos jogadores, como nos outros jogos locais (de 2 a 12 [proposta]). A ordem é **a da mesa** (dá pra arrumar na sala) e **quem começa é sorteado** [proposta].
2. Tela "Vez de **Ana**" com o botão **Pronto**, para o aparelho passar de mão.
3. O app toca a sequência atual e Ana repete.
   - **Acertou**: a sequência ganha **uma cor** e passa para o próximo jogador.
   - **Errou**: Ana sai. O próximo jogador recebe a **mesma sequência** que Ana errou (sem cor a mais) [proposta].
4. Quem sobrar por último **vence**. A classificação é pela ordem em que as pessoas saíram.
5. O primeiro jogador começa com **1 cor** [proposta].
6. Sem tela "passe para o próximo" escondendo nada: todo mundo pode assistir [decidido].
7. A partida vai para o Histórico, com a classificação e o tamanho máximo alcançado.

## 5. Corrida no Wi-Fi [decidido: rodadas juntas]

1. Sala de sempre (código, QR, lista de jogadores). O host joga também. De **2 a 12** jogadores [proposta]. Não há opções de host além de começar [proposta].
2. O host sorteia **uma sequência só** para todos.
3. Cada rodada começa com uma contagem **3-2-1** e a sequência toca **ao mesmo tempo** em todos os aparelhos, marcada pelo relógio sincronizado (`net/clock_sync.gd`) [proposta].
4. Cada um repete no seu tabuleiro. Quem termina (acertando ou errando) vê "Esperando os outros…" com **quantos ainda faltam**, sem dizer quem acertou [proposta].
5. Fim da rodada, quando **todos** terminam [decidido: esperar sempre]:
   - Quem errou **sai** e vira espectador (vê as telas de fim de rodada).
   - Se **todos** os que restavam erraram, **ninguém sai** e a rodada se repete com a **mesma sequência** [proposta: a mesma, e não uma nova].
   - Aparece a lista: quem passou ✓ e quem saiu ✗ nesta rodada.
6. Quem ficar sozinho **vence**. Se sobrar só um, ele **não precisa** jogar mais rodadas [proposta]. Classificação: pela rodada em que cada um saiu; quem saiu na mesma rodada **empata** [proposta].
7. Botão **Revanche** no fim.
8. Quem cai da rede e volta continua onde parou. Se todos os outros já terminaram, a rodada espera **15 s** por quem caiu e depois ele sai da partida [proposta: para não travar a rodada]. Quem chega no meio da partida **não entra** (como nos outros jogos) e espera o host voltar pra sala [proposta].
9. O host pode **remover** um jogador que travou a rodada (sem limite de tempo, é a única saída) [proposta].

## 6. Rede

- Base comum dos outros jogos: `PartyClockHost`/`PartyClockClient` em `games/tema_base`, a sala, o QR e o navegador (`net/web_gateway.gd`).
- O host manda a **sequência da rodada** e o horário de início no relógio sincronizado. Cada aparelho toca localmente [proposta]. A sequência vai ao cliente de qualquer forma (ele precisa tocá-la), então não há segredo a proteger.
- Cada jogador manda os toques; **o host confere** e decide acertou/errou [proposta], para que a regra fique num lugar só. Como não há corrida contra o tempo, não é preciso carimbo de horário nos toques.
- Web: `web/genius.js`, com o tabuleiro em SVG/CSS e Web Audio.

## 7. Telas e visual

- O tabuleiro é o **círculo clássico** dividido em 4 quartos, com o miolo central mostrando o placar (e o botão de começar) [proposta]. Em tablet, fica maior e centralizado. No celular deitado, também funciona [verificar: orientação do app].
- Cor apagada = tom escuro da cor; acesa = tom claro com brilho. Cada quarto tem um **símbolo discreto** para quem é daltônico [proposta].
- O visual é escolha minha e segue os tokens do app. Eu mostro capturas para você aprovar.

## 8. Arquitetura

- `games/genius/`, com `rules/` (lógica pura, `RefCounted`, testável: sequência, conferência, velocidades, eliminação), `screens/`, `ui/` (o tabuleiro) e `session/` (local e rede).
- `games/genius/audio/tone_player.gd`: gerador dos tons [proposta].
- Testes em `tests/`: velocidades por tamanho, conferência de toque, regra do Passa o aparelho (quem erra passa a mesma sequência), rodada da Corrida (sai quem errou, repete se todos erraram, empate) e protocolo de rede (`tools/party_net_test.sh genius` ou equivalente).

## 9. Propostas para você confirmar

1. A sequência pode repetir a mesma cor seguida (§2).
2. O botão fica aceso enquanto o dedo estiver apertado, com mínimo de 0,15 s; pausa de 1,3 s entre rodadas (§2).
3. Ao errar, o botão certo pisca (§2).
4. A sequência não tem fim; acima de 31 cores, só comemora e segue na velocidade máxima (§2.1).
5. Os tons são gerados pelo app, sem arquivos de áudio (§2.2).
6. Sair no meio do solo descarta a partida (§3).
7. Passa o aparelho: 2 a 12 jogadores, ordem da mesa com quem começa sorteado, o primeiro começa com 1 cor, e quem vem depois de quem errou recebe a mesma sequência (§4).
8. Corrida: 2 a 12 jogadores, sem opções de host, início pelo relógio sincronizado (§5).
9. Quem termina a rodada vê quantos faltam, mas não quem acertou (§5).
10. Se todos erram, a rodada se repete com a mesma sequência (§5).
11. Quem sobra sozinho vence sem jogar mais; quem sai na mesma rodada empata (§5).
12. Quem caiu tem 15 s depois que os outros terminaram; quem chega no meio não entra; o host pode tocar em "Não esperar" pra tirar quem travou a rodada (§5).
13. O host confere os toques; cada aparelho toca a sequência localmente (§6).
14. Tabuleiro em círculo com o placar no miolo e símbolos para daltônicos (§7).

## 10. Riscos

- **Nome "Genius"**: é marca da Estrela (e o jogo é o Simon, da Hasbro). Mesma questão do Halli Galli (P1).
- **Atraso do som no Android**: se o tom demorar a sair depois do toque, o jogo parece "mole". Precisa testar num aparelho de verdade [verificar].
- **Rodada que espera todo mundo**: sem limite de tempo, uma pessoa distraída trava a sala. Por isso a proposta 12.

## 11. Marcos (plano original)

1. Regras puras e gerador de tons, com testes.
2. Solo clássico com o tabuleiro e o recorde.
3. Passa o aparelho.
4. Corrida no app.
5. Corrida no navegador (`web/genius.js`).
6. Capturas para você aprovar e teste de atraso do som no celular.

## 12. O que foi feito

- **Regras** em `games/genius/rules/genius_rules.gd` (Passa o aparelho e Corrida no mesmo contrato dos jogos de tema), com testes em `tests/test_genius_rules.gd`.
- **Som** em `games/genius/audio/genius_tones.gd`: onda quadrada com filtro, gerada na hora. Notas 415/310/252/209 Hz e o buzz de 42 Hz.
- **Tabuleiro** em `games/genius/ui/genius_board.gd`: círculo com os 4 quartos, símbolos ● ▲ ■ ◆ e o placar no miolo. A sequência toca numa hora marcada: se a tela for remontada no meio, ela continua de onde estava.
- **Telas**: menu, solo (`genius_solo.gd`, recorde em `user://genius.cfg`), Passa o aparelho e Corrida (`genius_game.gd`, sobre o `PartyGameScreen`), criar sala (sem tabuleiro) e como jogar. O jogo aparece no início e no Entrar numa sala.
- **Rede**: `GeniusHost`/`GeniusClient` (host e cliente com relógio). A sequência começa numa hora do host; cada aparelho confere os toques na hora e o host decide.
- **Navegador**: `web/genius.js` e `web/genius.css`, com o tabuleiro em SVG, os tons em Web Audio e o relógio por pings.
- **Testes**: `tools/genius_net_test.sh` (host e 3 robôs; todos erram numa rodada, que se repete; um robô cai e volta; confere a classificação). Capturas com `--tour-set=genius`. A página do navegador foi jogada contra um host robô.
- **Falta**: testar num celular (atraso do som, §10), jogar com gente e aprovar o visual pelas capturas.
