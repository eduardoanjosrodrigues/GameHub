# gamehub — Plano do Halli Galli

> Status: v2 · 2026-09-26 · implementado (ver §13); falta testar em aparelhos reais
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
| Intervalo entre viradas | **Mínimo de 0,5 s entre duas viradas quaisquer** (era 1 s; reduzido depois de jogar), pra ninguém atropelar a mesa virando logo depois do outro |
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
- **Intervalo mínimo de 0,5 s entre viradas** [decidido]: o próximo só consegue virar 0,5 s depois da última carta virada na mesa. No Wi-Fi, o celular dele mostra a borda de "sua vez" enchendo durante esse meio segundo, e o arrastar só funciona quando ela completa. A conta usa o relógio sincronizado (§5.1), então vale igual pra todos.

### 3.4 O sino

- Qualquer jogador pode bater a qualquer momento, até na vez de outro.
- **Acertou** (exatamente 5 de alguma fruta somando as cartas de cima de todas as pilhas abertas): leva todas as pilhas abertas para o fundo do próprio monte, embaralhadas [proposta]. Quem acertou começa a próxima vez [proposta].
- **Errou** [corrigido por você em 2026-09-26]: primeiro, **todas as cartas abertas voltam pro fundo do monte de cada dono** (a mesa zera). Depois, quem bateu dá 1 carta do monte para cada outro jogador ainda no jogo. Se não tiver cartas para todos, dá o que tiver, seguindo a ordem da vez a partir do próximo [proposta]. **Numa partida que começou com 2 jogadores, a multa é de 3 cartas pro outro** [decidido em 2026-09-28]. Quem já tinha saído mas tinha carta na mesa recebe ela de volta e volta pro jogo [proposta].
- Depois de um sino (certo ou errado), ninguém vira carta por 1 s. Todo mundo vê o resultado e ninguém vira no susto [proposta].
- **Sino atrasado não pune** [proposta, veio na implementação]: durante esse 1 s, um sino errado não conta nem pune. É a mão que chega no sino que outro acabou de bater; sem isso, quem batesse 200 ms depois do vencedor pagaria carta. Um sino certo nesse 1 s (a mesa ainda tem 5 depois de um erro) vale normalmente.

### 3.5 Saída e vitória

- Quem fica sem monte fechado continua no jogo enquanto tiver carta aberta: pode bater o sino e voltar se ganhar a mesa.
- **Sem monte, a vez é pulada, mas a pessoa não sai** [decidido em 2026-09-28; antes saía quando chegava a vez dela, e no 1 contra 1 isso acabava a partida na hora]. Os outros seguem virando (no 1 contra 1, o outro vira sozinho) até alguém bater o sino. Só sai quem ficar sem carta nenhuma depois de um sino.
- **Ninguém com monte** [decidido em 2026-09-28]: a vez fica com o próximo da ordem, que arrasta pra desvirar a mesa: cada um pega a própria pilha aberta, embaralha e vira de novo como monte, e ele já vira a primeira carta. Sino com horário anterior a isso não conta.
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

- Cada cliente troca pings com o host: 12 rápidos (a cada 100 ms) logo ao entrar, pro relógio ficar bom em ~1 s, e depois 1 por segundo, no lobby e na partida. Os pings vão sem garantia de entrega (um ping atrasado atrapalha mais do que um perdido). Cada ping calcula a diferença entre os relógios assumindo que ida e volta levam o mesmo tempo, como no NTP.
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
5. **Só o primeiro sino da janela conta** (menor horário). Se ele estiver certo, leva a mesa; se estiver errado, a mesa volta pros donos e ele paga (§3.4). Em qualquer caso a mesa zera, então os sinos seguintes do mesmo momento são descartados, sem punição. No jogo físico, a mão que chega depois bate na mão de quem chegou primeiro.
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
├── session/                  # halli_local (mesa), halli_host e halli_client (Wi-Fi)
├── screens/                  # menu, criar sala, jogo Wi-Fi, jogo na mesa, como jogar
├── ui/                       # desenho das cartas e do sino, tela do jogador, mesa, resultados
└── art/, audio/
net/clock_sync.gd             # novo e reutilizável: ping, diferença de relógio, horário do host
net/room_probe.gd             # pergunta de qual jogo é uma sala antes de entrar
```

- `HalliRules` recebe ações **com horário** (`flip` com `t`, e `ring(sinos, agora)`) e mantém a linha do tempo da mesa (cada carta aberta guarda o instante em que foi virada), de modo que a mesa em qualquer instante `t` possa ser consultada.
- A janela de decisão (§5.3) fica na `HalliHost`, não nas regras: o host junta os sinos da janela e passa todos pra `ring()`, que ordena e julga. Isso continua testável sem rede.
- No modo mesa (`HalliLocal`) não há janela: cada toque vai direto pra `ring()`, e a regra do sino atrasado (§3.4) cuida dos toques quase juntos.
- O estado enviado a cada cliente é **filtrado**: ele recebe a própria carta aberta, a próxima carta do próprio monte, as contagens e de quem é a vez. Não recebe as cartas dos outros.

### 8.1 Mensagens (como ficou)

Protocolo do `Net` subiu pra versão 2 (entrou um canal sem garantia de entrega no sentido cliente → host). Aparelhos com versões diferentes do app não se falam.

| Direção | Tipo | Conteúdo |
|---|---|---|
| C→H | `qual_jogo` / H→C `jogo` | pergunta de qual jogo é a sala (entrar por código ou QR, §8.2) |
| C→H | `hello` | jogo, device_id, nome |
| C→H | `ping` / H→C `pong` | `c` (envio no relógio do cliente), `rtt` (maior ida e volta recente), `h` (relógio do host) |
| C→H | `acao` | `{type: "flip", t}`, `{type: "bell", t}` ou ações do host |
| H→C | `bem_vindo` | id, código da sala |
| H→C | `estado` | estado filtrado + eventos (`flip`, `turn`, `bell`, `undo_flip`, `out`, `paused`, `resumed`, `game_over`...) |
| H→C | `erro` | `acao` (ação recusada: o estado certo vem logo depois), `outro_jogo`, `partida_em_andamento`, `versao`... |

### 8.2 Entrar numa sala de qualquer jogo

A tela "Entrar numa sala" saiu do Chapéu e virou do hub (`app/screens/join_screen.gd`). Salas achadas na rede já dizem o jogo. Por código, IP ou QR, o app primeiro conecta e pergunta `qual_jogo` (`net/room_probe.gd`), desconecta e entra de novo já com a sessão certa.

### 8.3 Jogar pelo navegador (iPhone e quem não tem o app)

Vale pro Halli Galli e pro Chapéu (docs/PLANO_FASE_1.md não previa; entrou em 2026-09-26).

- Quem cria a sala no app (Android) abre também uma página na rede local: **http://IP:7780/**. O canal do jogo é um WebSocket na porta **7781**. As portas 8080/8081 ficaram de fora porque são comuns demais (no PC de desenvolvimento a 8080 já estava ocupada).
- Na sala, o QR tem duas opções: **Tem o app** (link `gamehub://`, como antes) e **Navegador (iPhone)** (o endereço da página). Abaixo do QR do navegador aparece o endereço pra digitar.
- A página é um cliente leve em HTML/JS (`web/`), não o Godot no navegador: abre na hora e não precisa instalar nada. Quem entra por ela é, pro host, um jogador como outro qualquer (`net/web_gateway.gd` dá a cada navegador um id de peer e troca as mesmas mensagens do `Net`, em JSON).
- No Android, a página mostra "Abrir no app" pra quem tem o gamehub instalado.
- **Halli Galli pelo navegador**: mesmos gestos (arrastar vira, toque duplo bate), relógio sincronizado por ping e o instante do toque vem do próprio evento de toque (`event.timeStamp`). O iPhone **não vibra** (o Safari não deixa); o resto funciona igual.
- **Chapéu pelo navegador**: todas as fases do jogador (escolher time, escrever palavras, escolher quem explica, explicar com Acertou/Pular/Pausar, adivinhar, resumo, fim). O tabuleiro continua só no app.
- Recarregar a página no meio da partida volta pro mesmo lugar (o aparelho guarda um id no navegador). O botão × da página sai de vez.
- Artes, fontes e sons da página ficam em `web/assets/`, copiados por `tools/sync_web_assets.sh` (cada cópia vai pro app sem conversão).

---

## 9. Queda de rede [decidido + proposta]

- Se alguém cai, a partida **pausa para todos**, e todos veem "Esperando **Ana** voltar...". O cliente tenta reconectar sozinho, como no Chapéu.
- O host pode **remover** quem não voltar ("Continuar sem Fulano"). Todas as cartas dessa pessoa, do monte e da mesa, são divididas uma a uma entre os outros, pro fundo do monte [proposta].
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
| **H3 — Relógio sincronizado** | `net/clock_sync.gd` + teste | Wi-Fi de casa (atraso extra médio de até 15 ms): erro abaixo de 5 ms. Rede ruim (média de 60 ms): erro abaixo de 20 ms |
| **H4 — Wi-Fi** | Lobby com ordem da mesa, tela do jogador, gestos, janela do sino, desfazer virada | Bot de rede com atrasos diferentes por jogador: quem toca antes sempre vence, independente do atraso |
| **H5 — Queda e polimento** | Pausa e reconexão, vibração, sons, arte, tela "como jogar" | Derrubar o Wi-Fi de um celular no meio da partida e ele voltar com as mesmas cartas |
| **H6 — Playtest** | Partida real com 4 ou mais celulares | Lista de ajustes resolvida, principalmente gestos e janela `J` |

---

## 12. Pendências (preciso da sua resposta)

| # | Pergunta |
|---|---|
| **P1** | O gamehub vai para a Play Store com o Chapéu. O Halli Galli entra nessa mesma build? Opções: (a) sim, com outro nome e outra arte só na versão da loja; (b) só numa build interna (instalada por APK), com o jogo escondido na versão da loja; (c) você não vai publicar o hub, e tudo fica interno. |
| **P2** | Revisar todas as **[proposta]**: distribuição com carta a mais, ordem no lobby (ficou com botões ↑ ↓ em vez de arrastar), primeiro jogador sorteado, quem ganha a mesa começa, trava de 1 s, punição quando faltam cartas, pilha de quem saiu continua valendo, só o primeiro sino da janela conta, quem saiu volta se a carta dele voltar da mesa, sino atrasado sem punição (§3.4), valores dos gestos (40 px, 300 ms, 80 px), janela `J`, padrões de vibração, sino tocando só em quem bateu, visual, o que acontece com quem é removido. |

---

## 13. Status da implementação (2026-09-26)

| Marco | Status |
|---|---|
| H1 Regras | ✓ `HalliRules` + 22 testes (`tests/test_halli_rules.gd`) |
| H2 Aparelho na mesa | ✓ layouts de 2 a 6, multitoque por área (conferido com toques simulados). Até 4 no celular, até 6 no tablet (tela com lado menor ≥ 3,4 pol.) |
| H3 Relógio sincronizado | ✓ `net/clock_sync.gd` + 4 testes (`tests/test_clock_sync.gd`) |
| H4 Wi-Fi | ✓ `tools/halli_net_test.sh`: 4 robôs, quem toca primeiro tem 200 ms de atraso de rede e ganhou 6 de 6 sinos; a diferença medida foi de 41–42 ms para 40 ms reais |
| H5 Queda e polimento | ✓ pausa e volta testadas pelos robôs; vibração, sons (sintetizados em `tools/audio/generate_audio.py`), arte em SVG, "como jogar", histórico |
| H6 Playtest | **Falta**: partida real com celulares |

Também mudou fora do jogo: a tela "Entrar numa sala" agora é do hub (§8.2), o início mostra os dois jogos, o histórico mostra partidas de Halli Galli, e dá pra jogar Halli Galli e Chapéu pelo navegador (§8.3), testado no navegador contra robôs.

Ainda não testado em aparelho real. Pontos pra olhar no playtest: se o toque duplo dispara sem querer, se o arrastar é confortável com o celular deitado, o tamanho da janela `J` no Wi-Fi de verdade, e se a vibração dá pra sentir com o celular na mesa.

