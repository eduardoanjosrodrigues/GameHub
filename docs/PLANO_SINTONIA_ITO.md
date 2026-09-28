# gamehub — Plano da Sintonia e do Ito

> Status: v2 · 2026-09-26 · implementado (ver §13); falta testar com pessoas
> Escopo: quinto e sexto jogos do hub, **Sintonia** (tipo Wavelength) e **Ito**. São dois jogos separados que usam a mesma base. Funcionam pelo **Wi-Fi** (app ou navegador, com **tabuleiro opcional**) e também com **um celular só**.

Legenda (a mesma dos outros planos): **[decidido]** veio das suas respostas; **[proposta]** é sugestão minha (lista em §10); **[verificar]** precisa ser confirmado.

---

## 1. Visão geral

Os dois jogos giram em torno de **uma escala e um tema**. A graça é dar uma dica que coloque um ponto nessa escala sem dizer números.

- **Sintonia**: o tema é um par de extremos ("Frio ↔ Quente"). Só quem dá a dica vê onde está o alvo. Essa pessoa fala uma dica ("café de padaria") e o time gira uma agulha até onde acha que o alvo está. Pode ser em **times** ou **cooperativo**.
- **Ito**: o tema é uma frase ("O quão assustador é um animal"), e cada um recebe um **número secreto de 1 a 100**. Cada pessoa fala um exemplo do tema que represente o seu número ("um gatinho" para um 5, "um tubarão" para um 90). O grupo então monta uma **fila em ordem crescente** e revela. É **cooperativo**.

O app faz o que o jogo físico faz com peças: esconde o alvo e os números, sorteia os temas, gira a agulha ao vivo em todas as telas, monta a fila e revela com suspense. A conversa continua na mesa.

## 2. Decisões [decidido]

| Área | Decisão |
|---|---|
| No hub | **Dois jogos separados**, cada um com o seu ícone, menu e "Como jogar", usando o **mesmo código de base** |
| Modos de aparelho | **Pela rede**: cada um no seu celular, pelo **app** (Android) ou pelo **navegador** (iPhone). O **tabuleiro é opcional**, como no Avalon, e a troca de aparelho funciona. **Um celular só**: o celular passa de mão em mão só na hora do segredo e depois fica no meio da mesa |
| Temas | **Uma lista minha, em português**, e dá para **digitar um tema na hora** |
| Timer | **Opcional, desligado por padrão**: o host liga na sala. Quando o tempo acaba, só avisa |
| **Sintonia**: modos | **Os dois**, escolhidos na sala: **times** (regra oficial) e **cooperativo** (regra oficial) |
| **Sintonia**: times | Montados **na sala**: o host arrasta as pessoas ou aperta **"Sortear times"**. Na revanche, os times continuam iguais |
| **Sintonia**: tema da rodada | Quem dá a dica **escolhe entre 2 temas sorteados** ou digita outro |
| **Sintonia**: agulha | **Qualquer um do time gira, ao vivo**, no próprio celular ou no tabuleiro, e todo mundo vê a agulha se mexer. Quando o time concorda, alguém aperta **"Travar"** |
| **Ito**: modos | **Os dois**, escolhidos na sala: **Desafio** (progressão oficial com vidas) e **Rodada solta** |
| **Ito**: jogo | **Montar a fila e revelar no fim**, que é a regra oficial da edição ocidental |
| **Ito**: dica | **Falada**, e cada um **pode escrever uma palavra-chave** se quiser; ela aparece junto da sua carta na fila |
| **Ito**: erro | A revelação vai **da esquerda para a direita**. Cada número menor que algum já revelado custa **1 vida** |
| **Ito**: progressão | **Oficial + vidas**: começa com 1 carta cada. A cada acerto, **uma pessoa ganha +1 carta** (vai rodando pela mesa). Quando todos têm 2, entra o **modo extremo** (a fila não mostra de quem é cada carta). São **3 vidas**, uma rodada com erro **repete o nível** com números novos, e com 0 vidas acaba |

## 3. Regras da Sintonia

### 3.1 Escala e alvo

- A agulha vai de **0 a 100**, desenhada como um meio disco (180°). A ponta esquerda é o primeiro extremo, e a direita o segundo.
- O alvo é sorteado entre 10 e 90, para caber inteiro [proposta]. Ele tem cinco faixas com a mesma largura, e cada faixa ocupa 4 unidades da escala:

| Faixa | Distância do centro do alvo | Pontos |
|---|---|---|
| Centro | até 2 | 4 |
| Do lado do centro | de 2 a 6 | 3 |
| Borda | de 6 a 10 | 2 |
| Fora | mais de 10 | 0 |

  [proposta: medi o disco do jogo físico, e o alvo inteiro ocupa uns 20% do meio círculo]. Se a agulha cair **exatamente na linha** entre duas faixas, vale a melhor (oficial).
- A agulha anda de 0,5 em 0,5 [proposta].

### 3.2 Modo times (oficial)

- De **4 a 12** jogadores [proposta], em **2 times** de pelo menos 2 pessoas.
- O time que começa é sorteado. O **outro time começa com 1 ponto** (oficial).
- Uma rodada:
  1. **Quem dá a dica** é a próxima pessoa do time da vez, rodando dentro do time.
  2. Essa pessoa vê o alvo e **escolhe um de 2 temas sorteados** (ou digita outro). Aí fala a dica em voz alta. O app não pede a dica escrita.
  3. **O time gira a agulha.** Todo mundo do time pode arrastar, ao vivo. Alguém do time aperta **"Travar"**.
  4. **O outro time aposta** se o centro do alvo está **à esquerda ou à direita** da agulha. Qualquer um desse time escolhe, pode trocar até alguém apertar "Travar".
  5. **Revela**: o alvo aparece, e o app soma os pontos. O time da vez ganha de 0 a 4. O outro time ganha **1 se acertou o lado**, **menos quando o time da vez acertou o centro (4)** (oficial).
  6. **Recuperação** (oficial): se o time da vez fez 4 e **ainda está perdendo**, joga de novo, com outra pessoa dando a dica.
- **Fim**: ganha quem chegar a **10 pontos** primeiro. Se os dois times passarem de 10 na mesma rodada, ganha quem tiver mais. Se empatar, joga-se **morte súbita**: uma rodada para cada time, até um ficar na frente (oficial).

### 3.3 Modo cooperativo (oficial)

- De **2 a 12** jogadores [proposta] (o oficial recomenda de 2 a 5, mas funciona com mais). Todo mundo está no mesmo time.
- São **7 rodadas**. A dica passa pela mesa, uma pessoa por rodada.
- Não tem aposta de esquerda ou direita.
- Pontos: **2 ou 3** como no modo times. O **centro vale 3**, mas **ganha uma rodada extra**.
- No fim, o app mostra a nota do grupo, pela tabela oficial traduzida:

| Pontos | Nota [proposta de texto] |
|---|---|
| 0–3 | "Tá ligado na tomada?" |
| 4–6 | "Desliga e liga de novo" |
| 7–9 | "Assopra o cartucho" |
| 10–12 | "Nada mal. Nada bom, mas nada mal" |
| 13–15 | "Quase!" |
| 16–18 | "Vocês venceram!" |
| 19–21 | "Na mesma sintonia" |
| 22–24 | "Cérebro galáctico" |
| 25+ | "🤯" |

## 4. Regras do Ito

### 4.1 Base (oficial, edição da Arcane Wonders)

- De **2 a 10** jogadores (o oficial sugere 3 ou mais).
- **Números de 1 a 100**, sem repetir, sorteados a cada rodada. Cada um vê só os seus.
- **Tema**: o app sorteia uma carta com **2 temas** (como a carta de dois lados). **Qualquer um** escolhe um deles para o grupo, ou digita outro [proposta].
- **Dica**: cada um fala um exemplo do tema que represente o seu número. **Não pode dizer números, valores nem quantidades** (oficial); o app avisa isso na tela. Pode mudar a dica quando quiser.
- **Fila**:
  - Quando a pessoa tem uma dica, **põe a carta na fila**: no começo, entre duas cartas ou no fim.
  - Se quiser, escreve uma **palavra-chave**, que aparece embaixo da carta.
  - **Qualquer um pode arrastar qualquer carta da fila**, ao vivo [proposta], enquanto o grupo discute. É como mexer nas cartas no meio da mesa.
  - Cada carta mostra o **nome do dono** (menos no modo extremo) e, se tiver, a palavra-chave.
- **Revelar**: quando todas as cartas estão na fila, aparece "Revelar". Quem aperta vê uma confirmação: "Todo mundo concorda com a ordem?". Aí **o host vira as cartas uma por uma**, da menor para a maior, tocando no monte (como no Halli Galli). Cada virada aparece em todos os aparelhos ao mesmo tempo; o resultado e "Próxima rodada" só aparecem depois da última. (Mudado em 2026-09-26: antes os números apareciam sozinhos a cada 0,6 s, rápido demais.)
- **Erro**: cada número **menor que algum já revelado antes dele** conta como 1 erro.

### 4.2 Modo Desafio [decidido + proposta nos detalhes]

- Começa com **1 carta para cada** e **3 vidas**.
- **Rodada sem erro**: sobe de nível. **Uma pessoa ganha +1 carta** na próxima rodada, e a vez vai rodando pela ordem da mesa, até todos terem 2 cartas (oficial).
- **Com todos em 2**: entra o **modo extremo** (oficial). Continua ganhando +1 carta por vez, mas a **fila não mostra de quem é cada carta**; só o dono vê a sua marcada. O teto é 100 cartas no total, mas na prática o grupo para bem antes.
- **Rodada com erro**: perde **1 vida por erro**, e o nível **se repete** com números novos.
- **0 vidas**: acaba. O app mostra até onde o grupo chegou ("Nível 7: 12 cartas na mesa") e guarda o **recorde** do grupo no histórico [proposta].

### 4.3 Rodada solta [decidido]

- Cada um tem **1 carta** e não tem vidas; o host pode subir para 2 ou 3 cartas cada na sala [proposta].
- Depois de revelar, mostra quantos ficaram fora de ordem e oferece "Outra rodada".

### 4.4 Fora do plano

O Ito japonês tem mais um modo, o **Akai-ito**, em que se juntam pares que somam 100. Não entra agora.

## 5. Um celular só [decidido + proposta nos detalhes]

Funciona como o passa-e-joga do Chapéu, com uma tela "Passe para Fulano, toque quando estiver com o celular" antes de cada segredo.

- **Sintonia**:
  - Só quem dá a dica pega o celular e vê o alvo e os temas; os outros não olham.
  - Aperta **"Esconder o alvo"** e o celular vai para o meio da mesa.
  - O time gira a agulha na tela, o outro time escolhe esquerda ou direita, e aí revela.
- **Ito**:
  - O celular passa por todos no começo da rodada; cada um vê os seus números e aperta "Esconder e passar".
  - Depois o celular fica no meio. A fila tem **só os nomes** até alguém encostar numa carta; aí aparecem as palavras-chave e a carta pode ser arrastada.
  - Para ver o próprio número de novo: "Meu número", escolhe o nome e vê por 3 segundos.
  - O modo extremo não existe nesse modo, porque o celular do meio não tem como saber quem está mexendo. O Desafio para no nível em que todos têm 2 cartas, e isso já é vitória.
- O timer e os temas digitados funcionam igual.

## 6. Telas

### 6.1 Sintonia, celular do jogador (app e navegador)

- **Sala**:
  - Modo (times ou cooperativo).
  - No modo times, os times com arrastar e "Sortear times".
  - Timer, QR e "Copiar endereço".
- **Quem dá a dica**:
  - Os 2 temas em cartões grandes, mais "Digitar outro".
  - Depois de escolher, o disco com o alvo aparece e fica só nesse celular, com "Esconder".
  - Enquanto o time gira, essa pessoa vê a agulha se mexer sobre o alvo (no físico, ela também vê). Ela não pode falar nada.
- **Time da vez**: o disco grande com a agulha para arrastar e o botão "Travar"; o tema e o nome de quem deu a dica ficam em cima.
- **Outro time**: vê a agulha ao vivo. Depois que o time trava, escolhe "Esquerda" ou "Direita" e aperta "Travar".
- **Revelar**: o alvo desliza para dentro do disco, os pontos sobem no placar, e aparece a mensagem de recuperação quando valer.
- **Placar** sempre em cima: os dois times e a meta de 10. No cooperativo, os pontos e as rodadas que faltam.
- **Fim**: quem venceu ou a nota do grupo, as rodadas (tema, dica escolhida, onde ficou a agulha, onde estava o alvo) e "Revanche".

### 6.2 Ito, celular do jogador (app e navegador)

- **Sala**: modo (Desafio ou Rodada solta), cartas por pessoa na Rodada solta, timer, QR e "Copiar endereço".
- **Tema**:
  - A carta com os 2 temas; qualquer um toca num deles ou em "Digitar outro".
  - Depois o tema escolhido fica fixo no topo.
- **Minha mão**: os meus números em cartas grandes, cada uma com o campo opcional de palavra-chave e o botão "Pôr na fila". Tem "Esconder", como o "Meu papel" do Avalon.
- **A fila**: horizontal e rolável, com o **0** fixo no começo. Cada carta é arrastável e mostra o nome e a palavra-chave. A minha carta aparece destacada e mostra o meu número só para mim.
- **Revelar**: a confirmação e depois um monte de cartas de costas (pulsando no aparelho do host) ao lado de uma pilha com a última carta virada. Cada toque do host gira a próxima carta na pilha, com o dono, a palavra-chave e "Em ordem" ou "Fora de ordem!"; embaixo, "Próxima: fulano" e "Tem que ser maior que N". As fora de ordem ficam vermelhas, tremem e quebram um coração na hora. A fila com o fio vai se enchendo de números embaixo.
- **Fim de rodada**: "Acertaram! Nível 4" ou "2 erros, −2 vidas". Na Rodada solta, só o placar.
- **Fim do Desafio**: o nível alcançado, o recorde e "Jogar de novo".

### 6.3 Tabuleiro (app ou navegador, tela grande)

- **Sintonia**:
  - O disco grande, com a agulha ao vivo, o tema e o placar.
  - Dá para girar a agulha no tabuleiro também. O time da vez arrasta, e o outro time escolhe o lado nele.
  - **Nunca mostra o alvo antes da revelação.**
- **Ito**:
  - O tema, a fila grande, as vidas e o nível.
  - Dá para arrastar as cartas no tabuleiro.
  - Nunca mostra os números antes da revelação.
- Na sala, os dois mostram o QR grande e a lista de quem entrou, como os outros jogos.

### 6.4 Cuidados para não vazar informação [proposta]

- Na Sintonia, o alvo só chega ao celular de quem dá a dica. O tabuleiro e os outros celulares recebem só a agulha, até a revelação.
- No Ito, **o número de cada carta só chega ao dono**. O tabuleiro e os outros recebem a fila com o dono e a palavra-chave. No modo extremo, recebem só a fila, sem os donos.
- O app não bloqueia palavras-chave com números; isso fica com o grupo, como no físico [proposta]. Ele só mostra o lembrete.

## 7. Temas [decidido: minha lista + digitar na hora]

- **Sintonia**: umas **300 duplas** de extremos, escritas por mim em português. Vão de coisas fáceis ("Frio ↔ Quente") a subjetivas ("Superestimado ↔ Subestimado") e com a nossa cara ("Comida de vó ↔ Comida de restaurante", "Jogador perna de pau ↔ Craque").
- **Ito**: uns **200 temas** de frase ("O quão útil numa ilha deserta", "O quão chique é uma comida", "O quão famoso é um brasileiro").
- Tudo sai da minha cabeça. **Não copio as cartas dos jogos originais.**
- Ficam em arquivos de texto (`games/sintonia/data/temas.txt`, `games/ito/data/temas.txt`), um por linha. Fica fácil você editar e mandar mais.
- O mesmo tema não se repete na sessão até a lista acabar [proposta].

## 8. Rede

- Igual aos outros jogos:
  - Host autoritativo, com `Net` (ENet) para o app e `WebGateway` para o navegador.
  - Cada aparelho recebe o estado filtrado para quem ele é.
  - Descoberta, QR, código, reconexão e troca de aparelho funcionam como hoje.
- **A novidade é o movimento ao vivo**: a agulha da Sintonia e o arrasto das cartas do Ito.
  - O celular manda a posição até **15 vezes por segundo** enquanto a pessoa arrasta [proposta], e o host repassa para todos.
  - **Vale o último que mexeu.** Se duas pessoas arrastarem juntas, a agulha segue quem mandou por último, como duas mãos no disco físico.
  - No fim do arrasto, o celular manda a posição final, e o host confirma.
- **Queda no meio**: o jogo segue [proposta].
  - Se cair quem dá a dica na Sintonia, o jogo espera essa pessoa ou a troca de aparelho.
  - No Ito, as cartas de quem caiu ficam onde estão, e dá para revelar mesmo assim.

## 9. Arte e arquitetura

**Arte** [proposta, minha escolha]:
- Tudo em **SVG, no traço do hub**, sem precisar de imagem do Nano Banana:
  - o disco da Sintonia, em leque colorido com a agulha;
  - as cartas numeradas do Ito, com um fio vermelho ligando as cartas na fila ("ito" quer dizer fio em japonês);
  - corações para as vidas;
  - os ícones dos dois jogos.
- Se você quiser capas ilustradas depois, eu escrevo os prompts.

**Arquitetura** [proposta]:

```
games/tema_base/             # compartilhado: sorteio de temas, digitar tema, timer, passa-e-joga
games/sintonia/
├── rules/sintonia_rules.gd  # puro, com semente, testável: alvo, pontos, times, recuperação, cooperativo
├── session/  screens/  ui/  # sessões copiadas do Avalon; ui com o disco
└── data/temas.txt
games/ito/
├── rules/ito_rules.gd       # puro: números, fila, revelação, erros, vidas, progressão, extremo
├── session/  screens/  ui/  # ui com a fila e as cartas
└── data/temas.txt
web/sintonia.js, web/ito.js
tests/test_sintonia_rules.gd, tests/test_ito_rules.gd
tools/sintonia_bot.gd, tools/ito_bot.gd, tools/*_net_test.sh
```

Diferente do Avalon e do Secret Hitler, aqui **faz sentido extrair a base** desde o começo, porque os dois jogos nascem juntos. O que fica comum: temas, timer, passa-e-joga e a mensagem de "mover ao vivo". O Avalon não é mexido.

## 10. Marcos

| Marco | Entrega | Critério de pronto |
|---|---|---|
| T1 Base e regras | Temas, `SintoniaRules`, `ItoRules` + testes | Faixas e empate na linha; aposta de lado e exceção do centro; recuperação; fim com passagem de 10 e morte súbita; cooperativo com 7 rodadas, bônus e nota. Números sem repetir; erros da revelação; vidas; progressão até 2 e extremo; repetir nível; filtro do que cada um vê |
| T2 Ito rede e app | Sessões, sala, telas, tabuleiro | Partida inteira com robôs, com os robôs conferindo que ninguém recebe número alheio |
| T3 Sintonia rede e app | Idem, com a agulha ao vivo | Idem, com o alvo |
| T4 Navegador | `web/ito.js`, `web/sintonia.js` | Partida com o navegador no meio dos robôs, arrastando a agulha e a fila |
| T5 Um celular só | Passa-e-joga nos dois | Capturas de todas as telas nos dois modos |
| T6 Temas e arte | As duas listas, SVGs, ícones | Você lê as listas e aprova |
| T7 Playtest | Partida real | Lista de ajustes resolvida |

Ordem [proposta]: **Ito primeiro**, que tem menos movimento ao vivo, e a Sintonia logo depois, na mesma base.

## 11. Riscos

| Risco | Mitigação |
|---|---|
| Agulha travando ou pulando no Wi-Fi | Manda no máximo 15 por segundo, o celular de quem arrasta mostra a própria posição na hora, e os outros suavizam |
| Duas pessoas arrastando juntas | Vale o último, e aparece "Ana está mexendo" |
| Fila longa no Ito (10 pessoas com 2 cartas, 20 cartas) não cabe no celular | A fila rola na horizontal, com cartas compactas; o tabuleiro mostra tudo |
| Temas ruins ou sem graça | Lista em arquivo de texto para você editar, e digitar na hora |
| Nome e marca | Wavelength e ito são marcas registradas; as regras de jogo não têm direito autoral. O nome "Sintonia" já é nosso. Para "Ito", ver §12, P2 |

## 12. Pendências

| # | Pergunta |
|---|---|
| **P1** | Revisar as **[proposta]**: tamanho do alvo e passo da agulha (§3.1), número de jogadores (§3.2, §3.3), textos da nota (§3.3), qualquer um arrasta qualquer carta (§4.1), recorde do Desafio e cartas da Rodada solta (§4.2, §4.3), detalhes do celular só e sem extremo nele (§5), cuidados (§6.4), temas sem repetir (§7), 15 por segundo e queda (§8), arte só em SVG (§9), Ito primeiro (§10) |
| **P2** | Nome do Ito no hub: **"Ito"** (o app é interno) [proposta]. Se um dia for para a Play Store, troca para "Fio" |

## 13. Status da implementação (2026-09-26)

Feito: T1 a T6. Falta o T7, o playtest.

- **Base comum** (`games/tema_base/`):
  - sessões genéricas `PartyHost`, `PartyClient` e `PartyLocal` (celular só);
  - tela base `PartyGameScreen`, com sala, QR, troca de aparelho, janelas por cima e "passe o celular";
  - `PartyMenu`, `PartyCreateRoom`, `PartyHowTo`, `ThemeBank` e `TapPanel`.
- **Regras** (`ItoRules`, `SintoniaRules`): 18 testes em `tests/`. Todas as regras de §3 e §4 estão lá, inclusive recuperação, morte súbita, cooperativo com rodada extra, modo extremo e celular só sem extremo.
- **Telas**:
  - celular do jogador, tabuleiro e celular só nos dois jogos;
  - na fila do Ito, toca-se na carta e depois em "Colocar aqui" (mais seguro que arrastar numa tela que rola);
  - a agulha da Sintonia é ao vivo e não remonta a tela.
- **Navegador**: `web/ito.js` e `web/sintonia.js`. A agulha é arrastável (pointer events) e as outras telas só movem a agulha.
- **Rede**: `tools/party_bot.gd` e `tools/party_net_test.sh ito|sintonia`, com 5 jogadores, 1 tabuleiro e uma queda. Os robôs conferem que ninguém recebe número alheio nem o alvo antes da hora.
- **Temas**: 323 pares da Sintonia e 216 frases do Ito, em `games/*/data/temas.txt`.
- **Arte**: tudo em SVG, com o ícone de cada jogo, o disco, as cartas com o fio vermelho e os corações.
