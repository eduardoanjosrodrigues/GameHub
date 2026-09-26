# gamehub — Plano do Halli Galli

> Status: v1 · 2026-09-26 · especificação, nada implementado ainda
> Escopo: segundo jogo do hub, o **Halli Galli**, em dois modos: **Wi-Fi** (principal) e **aparelho na mesa**.

Legenda (a mesma do [PLANO_FASE_1.md](PLANO_FASE_1.md)):

- **[decidido]**: veio das suas respostas.
- **[proposta]**: sugestão minha, precisa do seu ok (tudo listado em §12).
- **[verificar]**: fato técnico que precisa ser confirmado durante a implementação.

---

## 1. Visão geral

No Halli Galli, cada jogador vira uma carta do próprio monte na sua vez. Quando as cartas visíveis na mesa somam **exatamente 5 de uma mesma fruta**, quem bater o sino primeiro leva todas as cartas abertas. Vence quem ficar por último com cartas.

A graça está na velocidade de reação. Por isso, no modo Wi-Fi, a coisa mais importante é **decidir com justiça quem bateu primeiro** (§5).

### O que NÃO entra agora [decidido]

- Variações (Halli Galli Extreme, cartas especiais, outras frutas). Só a regra clássica.
- Tablet ou TV no meio como tela da mesa, no modo Wi-Fi.
- Nome e visual próprios: o app é de uso interno, então usa o nome e a estética do Halli Galli (ver risco em §10).

---

## 2. Decisões consolidadas [decidido]

| Área | Decisão |
|---|---|
| Modos | **Wi-Fi** (principal, prioridade de qualidade) e **aparelho na mesa** |
| Wi-Fi: o que cada celular mostra | **Só o seu monte e a sua carta.** O celular fica deitado na mesa na frente do jogador, e os outros olham para ele como se fosse a carta física |
| Wi-Fi: jogadores | Quantos quiser (mínimo 2) |
| Wi-Fi: host | Quem cria a sala também joga, como no Chapéu |
| Aparelho na mesa | Até **4 no celular**, até **6 no tablet** |
| Virar a carta | Cada um vira a sua, na sua vez |
| Gestos no Wi-Fi | **Arrastar** em qualquer parte da tela vira a carta; **toque duplo** em qualquer parte bate o sino |
| Gestos no aparelho na mesa | Arrastar na sua área vira; **botão de sino** na área de cada um |
| Fim da partida | Último que sobrar com cartas (clássico) |
| Baralhos | O host escolhe quantos |
| Vez lenta | Espera sem limite (clássico) |
| Sino errado | Paga 1 carta para cada outro jogador (clássico) |
| Monte vazio | Continua no jogo enquanto tiver carta aberta na mesa; sai quando chega a vez e não há o que virar |
| Quase empate | Vence o horário exato do toque, mesmo por 1 ms |
| Queda de rede | A partida pausa e espera a pessoa voltar |
| Vibração e toque | Uso caprichado de vibração e gestos que funcionam com o celular deitado na mesa |

---

## 3. Regras

### 3.1 Baralho

- 56 cartas por baralho, 4 frutas (banana, morango, limão, ameixa), 14 cartas de cada fruta [verificar contra o jogo original]:

| Frutas na carta | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Cartas por fruta | 5 | 3 | 3 | 2 | 1 |

- O host escolhe de 1 a 4 baralhos. Valor inicial: 1 baralho a cada 6 jogadores, arredondando para cima [proposta].

### 3.2 Preparação

- Embaralha tudo e distribui igual. Se não der certinho, os primeiros da ordem recebem uma carta a mais [proposta].
- Cada jogador tem um **monte fechado** e, à frente, uma **pilha aberta** (começa vazia). Só a carta de cima da pilha aberta conta.
- **Ordem da vez**: no lobby, o host arrasta os nomes para ficar na mesma ordem em que as pessoas estão sentadas [proposta]. Quem começa é sorteado [proposta].

### 3.3 A vez

- O jogador da vez vira a carta de cima do monte fechado para a pilha aberta. Depois a vez passa para o próximo da ordem.
- Não há limite de tempo.

### 3.4 O sino

- Qualquer jogador pode bater a qualquer momento, até na vez de outro.
- **Acertou** (exatamente 5 de alguma fruta somando as cartas de cima de todas as pilhas abertas): leva todas as pilhas abertas para o fundo do próprio monte, embaralhadas [proposta]. Quem acertou começa a próxima vez [proposta].
- **Errou**: dá 1 carta do monte fechado para cada outro jogador ainda no jogo. Se não tiver cartas para todos, dá o que tiver, seguindo a ordem da vez a partir do próximo [proposta].
- Depois de um sino (certo ou errado), ninguém vira carta por 1 s. Todo mundo vê o resultado e ninguém vira no susto [proposta].

### 3.5 Saída e vitória

- Quem fica sem monte fechado continua no jogo enquanto tiver carta aberta: pode bater o sino e voltar se ganhar a mesa.
- Quando chega a vez de alguém sem monte fechado, essa pessoa sai. A pilha aberta dela continua na mesa, valendo, até alguém ganhar a mesa [proposta].
- Quem sai da partida não bate mais o sino.
- Vence o último jogador com cartas.

---

## 4. Modos de jogo

### 4.1 Wi-Fi (principal)

**Entrar na sala**: igual ao Chapéu (descoberta automática, QR, código), reusando `net/`. A sala some da descoberta quando a partida começa, e quem cai volta pelo `device_id`.

**Tela do jogador durante a partida** (celular deitado na mesa):

- **A carta aberta**, enorme, ocupando quase toda a tela. As frutas ficam arrumadas de forma simétrica, legíveis de qualquer lado da mesa, e a carta não tem texto.
- **Quantas cartas faltam** no monte fechado, pequeno, num canto, virado para o dono.
- **É a sua vez**: borda grossa colorida e pulsando em volta da tela, mais vibração (§6). Dá para ver do outro lado da mesa de quem é a vez.
- **Nome** do jogador, pequeno, na base.

**Gestos**:

- **Arrastar** em qualquer direção, com pelo menos ~40 px [proposta], vira a carta. Fora da sua vez, o gesto não faz nada e o celular dá uma vibração curta de "não é sua vez" [proposta].
- **Toque duplo** em qualquer lugar bate o sino. O intervalo máximo entre os toques é de 300 ms [proposta]. O horário que vale é o do **segundo toque**.
- Um toque simples não faz nada, para ninguém bater sem querer ao encostar no celular.

**Tela ligada**: a tela não apaga durante a partida (`DisplayServer.screen_set_keep_on`).

**Depois do sino**, cada celular mostra por ~1 s [proposta]:

- Quem ganhou: "+N cartas", animação da mesa indo para o monte, e quantos ms de vantagem teve se foi apertado (menos de 100 ms) [proposta].
- Quem errou: "Errou! −N cartas".
- Os outros: a carta aberta some (se alguém ganhou a mesa) ou "+1 de Fulano" (se alguém errou).

**Lobby**: lista de jogadores na ordem da mesa (o host arrasta), número de baralhos e botão Iniciar (só para o host).

### 4.2 Aparelho na mesa

- O celular ou tablet fica deitado no meio. A tela é dividida em áreas, uma por jogador, cada uma virada para o seu lado da mesa:
  - 2 jogadores: metade de cima e metade de baixo, frente a frente.
  - 3 a 4: um lado da tela para cada um [proposta].
  - 5 a 6 (só tablet): 2 em cada lado comprido e 1 em cada ponta [proposta].
- Cada área tem: monte fechado com contador, carta aberta, **botão de sino** e destaque de "sua vez".
- **Arrastar** dentro da sua área vira a carta. **Tocar no seu sino** bate.
- O multitoque é tratado por dedo, então várias pessoas podem tocar ao mesmo tempo. Aqui é tudo no mesmo aparelho, então o primeiro toque registrado ganha, sem problema de justiça.
- Como o sino é um toque só, fica mais fácil bater sem querer. Por isso o botão fica afastado da carta e do monte [proposta].
- Nomes: cada jogador digita o seu na tela de preparação, como no passa-e-joga do Chapéu.

---

## 5. Justiça no Wi-Fi (o ponto crítico)

A rede entrega mensagens com atrasos diferentes (de 5 a 50 ms, e às vezes 200 ms ou mais com a economia de energia do Wi-Fi no Android). Se o host decidisse pela **ordem de chegada**, quem estivesse com o sinal pior perderia sempre. O plano é decidir pelo **instante do toque**, medido em cada celular num relógio comum.

### 5.1 Relógio sincronizado [proposta]

- Cada cliente troca pings com o host (a cada 1 s no lobby, e a cada 2 s durante a partida). Cada ping calcula a diferença entre os relógios assumindo que ida e volta levam o mesmo tempo, como no NTP.
- O app guarda as últimas ~20 medições e usa as de **menor tempo de ida e volta**, que são as mais precisas. Numa rede local isso dá precisão de poucos milissegundos.
- Todo evento importante (virar, bater) é marcado no celular com `Time.get_ticks_usec()` e convertido para o **horário do host**.

### 5.2 Virar a carta

- O host manda para cada jogador, com antecedência, qual é a próxima carta do monte dele (só para ele). Assim, ao arrastar, a carta aparece **na hora**, sem esperar a rede.
- O celular manda `{type: "virar", t}`. O host registra a virada com o horário `t`, e isso monta a **linha do tempo da mesa**.

### 5.3 Bater o sino

1. O celular manda `{type: "sino", t}` assim que reconhece o toque duplo.
2. Ao receber o primeiro sino, o host espera uma **janela** `J` antes de decidir, para dar tempo de chegarem sinos de quem tocou antes mas está com a rede mais lenta.
   - `J` = maior atraso de ida medido entre os jogadores + 40 ms de folga, com mínimo de 80 ms e máximo de 300 ms [proposta].
3. Entre os sinos recebidos, vence o de **menor `t`**.
4. A validade é julgada **pela mesa no instante `t`**, não na chegada:
   - Bateu antes da carta que fez 5 aparecer: **errou** (bateu cedo demais).
   - Bateu depois de uma nova carta desfazer o 5: **errou**.
5. Os outros sinos da janela são descartados, sem punição [proposta]. No jogo físico, a mão que chega depois bate na mão de quem chegou primeiro.
6. Se alguém virou uma carta com `t` **depois** do sino vencedor, essa virada é desfeita e a carta volta ao monte com animação. Isso deve ser raro por causa da trava de 1 s de §3.4.

### 5.4 O que continua injusto (e aceitamos)

- A **latência da tela de toque** varia de aparelho para aparelho (em torno de 20 a 80 ms). Não dá para medir isso direito sem calibrar cada aparelho, o que fica para depois se incomodar.
- Um sino que chega depois do fim da janela (rede muito ruim naquele instante) é ignorado. O celular mostra "sinal fraco" quando o ping passa de 150 ms [proposta].

### 5.5 Ver os tempos

- No fim de cada sino disputado, todos veem quem bateu e com quantos ms de diferença. Isso ajuda a confiar no sistema e a achar bugs no playtest.

---

## 6. Vibração e som

Com o celular deitado na mesa, a vibração também faz barulho na mesa, e é o principal aviso de "sua vez". Os padrões precisam ser fáceis de distinguir pelo tato [proposta]:

| Evento | Vibração | Som |
|---|---|---|
| Sua vez | 2 pulsos (40 ms, pausa, 40 ms) | — |
| Virou sua carta | 1 toque curto (15 ms) | Carta deslizando |
| Toque duplo reconhecido | 1 toque firme (25 ms), na hora, antes da resposta do host | Sino, **só no celular de quem bateu** |
| Você ganhou a mesa | Vibração longa (200 ms) | Cartas se juntando |
| Você errou | 3 pulsos rápidos | "Erro" grave |
| Recebeu carta de punição | 1 toque leve | — |
| Não é sua vez (arrastou fora da vez) | 1 toque bem leve (10 ms) | — |
| Você saiu | Vibração longa e fraca | — |
| Você venceu | Padrão de comemoração | Fanfarra |

- Tudo respeita a opção de vibração e os volumes das Configurações.
- O Godot só tem `Input.vibrate_handheld(ms, amplitude)`. Padrões com pausa são feitos com timers, e a amplitude depende do aparelho aceitar [verificar].

---

## 7. Visual [proposta]

- Identidade própria do jogo, perto do Halli Galli original: cartas brancas de cantos arredondados, frutas ilustradas grandes (banana amarela, morango vermelho, limão verde, ameixa roxa) e sino dourado.
- O resto da interface (lobby, menus) segue a papelaria do hub (§7 da Fase 1).
- Frutas, carta, verso e sino em SVG gerado no projeto. Eu escolho o visual e mostro capturas, como na Fase 1.

---

## 8. Arquitetura

Segue o mesmo princípio do Chapéu (regras separadas de tela e de rede):

```
games/halli_galli/
├── rules/halli_rules.gd      # estado + apply(ação) → eventos; puro, com semente, testável
├── session/                  # local_session, host_session, client_session
├── screens/                  # menu, lobby, jogo Wi-Fi, jogo na mesa, como jogar
└── art/, audio/
net/clock_sync.gd             # novo e reutilizável: ping, diferença de relógio, horário do host
```

- `HalliRules` recebe ações **com horário** (`virar(jogador, t)`, `sino(jogador, t)`) e mantém a linha do tempo da mesa, de modo que a validade de um sino em qualquer instante `t` possa ser consultada.
- A janela de decisão (§5.3) fica na `host_session`, não nas regras. As regras só recebem o sino vencedor já escolhido e os outros descartados, e isso continua testável.
- O estado enviado a cada cliente é **filtrado**: ele recebe a própria carta aberta, a próxima carta do próprio monte, as contagens e de quem é a vez. Não recebe as cartas dos outros.

### 8.1 Mensagens (primeira versão) [proposta]

| Direção | Tipo | Conteúdo |
|---|---|---|
| C→H | `hello` | device_id, nome |
| C→H | `ping` / H→C `pong` | t_envio_cliente, t_host |
| C→H | `virar` | t (horário do host) |
| C→H | `sino` | t |
| H (host local) | `ordem`, `baralhos`, `iniciar`, `remover` | parâmetros |
| H→C | `estado` | estado filtrado + eventos |
| H→C | `resultado_sino` | vencedor, certo/errado, fruta, diferença em ms para o segundo |
| H→C | `desfazer_virada` | jogador |
| H→C | `pausa` / `retomar` | quem caiu |

---

## 9. Queda de rede [decidido + proposta]

- Se alguém cai, a partida **pausa para todos**, e todos veem "Esperando **Ana** voltar...". O cliente tenta reconectar sozinho, como no Chapéu.
- O host pode **remover** quem não voltar. As cartas do monte fechado dessa pessoa são divididas entre os outros, e a pilha aberta dela sai da mesa [proposta].
- Se o host cair, todos veem "Esperando o host", sem migração de host (como no Chapéu).
- Sinos e viradas feitos durante a pausa são ignorados.

---

## 10. Riscos

| Risco | Impacto | Mitigação |
|---|---|---|
| **Nome e arte do Halli Galli numa build da Play Store** | O hub está sendo preparado para a loja (Fase 1). Se o jogo for junto com esse nome e esse visual, pode dar remoção por marca registrada (Amigo Spiele) | Ver pendência P1 |
| Economia de energia do Wi-Fi do Android segura pacotes | Atrasos de 100 a 300 ms às vezes | O horário do toque resolve a justiça. A janela `J` se adapta. Ver se dá para ativar o modo de baixa latência do Wi-Fi (`WifiManager` low-latency lock) sem plugin nativo [verificar] |
| Latência de toque diferente entre aparelhos | Aparelho lento perde por ~30 ms | Aceito por enquanto (§5.4); calibração fica para depois |
| Relógio do celular andando em ritmo diferente | Horários vão se desencontrando | Ping contínuo durante a partida (§5.1) |
| Toque duplo lido errado (dois dedos, palma, tela molhada) | Sino sem querer | Exigir os dois toques perto um do outro (até ~80 px) [proposta]; testar no playtest |
| Tela apagando ou app indo para o fundo | Jogador "cai" | Tela sempre ligada; ao voltar do fundo, reconecta |
| Só um celular para testar | Justiça do sino só aparece com aparelhos reais | Bot de rede com atraso artificial (§11) e playtest cedo com celulares da galera |

---

## 11. Marcos

| Marco | Entrega | Critério de pronto |
|---|---|---|
| **H1 — Regras** | `HalliRules` + testes | Testes cobrindo: contagem de 5 com várias pilhas, sino no instante antes e depois da carta, erro com poucas cartas, sair na vez, voltar ao jogo ganhando a mesa, vários baralhos, vencedor |
| **H2 — Aparelho na mesa** | Telas e layouts de 2 a 6, multitoque por área | Partida completa no celular (2 e 4) e no emulador de tablet (6) |
| **H3 — Relógio sincronizado** | `net/clock_sync.gd` + teste | Com atraso artificial de 0 a 200 ms e variação, a diferença estimada fica a menos de 5 ms do real |
| **H4 — Wi-Fi** | Lobby com ordem da mesa, tela do jogador, gestos, janela do sino, desfazer virada | Bot de rede com atrasos diferentes por jogador: quem toca antes sempre vence, independente do atraso |
| **H5 — Queda e polimento** | Pausa e reconexão, vibração, sons, arte, tela "como jogar" | Derrubar o Wi-Fi de um celular no meio da partida e ele voltar com as mesmas cartas |
| **H6 — Playtest** | Partida real com 4 ou mais celulares | Lista de ajustes resolvida, principalmente gestos e janela `J` |

---

## 12. Pendências (preciso da sua resposta)

| # | Pergunta |
|---|---|
| **P1** | O gamehub vai para a Play Store com o Chapéu. O Halli Galli entra nessa mesma build? Opções: (a) sim, com outro nome e outra arte só na versão da loja; (b) só numa build interna (instalada por APK), com o jogo escondido na versão da loja; (c) você não vai publicar o hub, e tudo fica interno. |
| **P2** | Revisar todas as **[proposta]**: distribuição com carta a mais, ordem arrastada no lobby, primeiro jogador sorteado, quem ganha a mesa começa, trava de 1 s, punição quando faltam cartas, pilha de quem saiu continua valendo, sinos da janela descartados sem punição, valores dos gestos (40 px, 300 ms, 80 px), janela `J`, padrões de vibração, sino tocando só em quem bateu, visual, o que acontece com quem é removido. |
