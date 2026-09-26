# gamehub — Plano do Coup

> Status: v3 · 2026-09-26 · implementado (ver §11); faltam os retratos do Nano Banana e testar com pessoas
> Escopo: oitavo jogo do hub, **Coup** (base + variante oficial do Inquisidor). Pelo **Wi-Fi**, cada um no seu celular (app ou navegador), com **tabuleiro opcional**, como o Avalon.

Legenda (a mesma dos outros planos): **[decidido]** veio das suas respostas; **[proposta]** é sugestão minha (lista em §10); **[verificar]** precisa ser confirmado.

---

## 1. Visão geral

Jogo de blefe, de 2 a 6 pessoas. Cada um tem **2 cartas de influência** viradas para baixo e moedas. Na sua vez, você faz uma ação e pode dizer que tem **qualquer personagem**, verdade ou mentira. Os outros podem **desafiar** (quem errou perde uma influência) ou **bloquear** com o personagem certo. Quem perde as duas influências sai. Ganha o último que sobrar.

O app faz o trabalho chato: guarda as cartas escondidas no celular, conta as moedas, sabe quem pode bloquear o quê, confere o desafio e revela e troca a carta sozinho. O blefe e a conversa ficam na mesa.

## 2. Decisões [decidido]

| Área | Decisão |
|---|---|
| Versão | **Base + Inquisidor**: na sala, o host escolhe **Embaixador** ou **Inquisidor** (variante oficial da Reforma) |
| Jogadores | **2 a 6**, com a **regra oficial de 2** |
| Reação (o ponto crítico) | **Sem "Deixa passar" e sem cronômetro visível.** Toda ação que dá para desafiar ou bloquear espera **no mínimo 5 s** antes de valer, para dar tempo de reagir. Na tela ficam só **"Desafiar"** e **"Bloquear"**. Se ninguém reage em 5 s, a ação vale |
| Quais ações esperam | **Todas as que dá para desafiar ou bloquear**: as de personagem (Imposto, Assassinar, Extorquir, Trocar, Examinar) e a Ajuda Externa. **Renda** e **Golpe de Estado** valem na hora |
| Bloqueio | **Todos recebem os botões "Desafiar o bloqueio" e "Aceitar"**, e qualquer um pode desafiar (como no oficial). O jogo **só avança quando quem foi bloqueado aceita**, ou quando alguém desafia. Sem tempo |
| Reações ao mesmo tempo | **Vale quem apertou primeiro**, pelo mesmo relógio justo do sino do Halli Galli |
| Nome e arte | **Coup**, com nomes em português; retratos pelo **Nano Banana**, no mesmo estilo do Avalon |
| Aparelhos | Igual ao Avalon: cada um no seu celular (app ou navegador), tabuleiro opcional, troca de aparelho |

## 3. Regras

### 3.1 Cartas e começo

- **Baralho da corte**: 15 cartas, 3 de cada: **Duque, Assassino, Capitão, Condessa** e **Embaixador** (ou **Inquisidor**, se o host escolher).
- Cada um recebe **2 cartas** viradas para baixo e **2 moedas**. O resto fica no baralho.
- **Com 2 jogadores** (regra oficial):
  - as cartas são separadas em 3 conjuntos de 5 (um de cada personagem);
  - cada um recebe um conjunto e **escolhe 1 carta** no celular, e as outras 4 saem do jogo;
  - o terceiro conjunto é embaralhado; cada um recebe 1 carta dele, e as 3 que sobram viram o baralho;
  - quem começa recebe **1 moeda** em vez de 2.
- Quem começa é sorteado; a vez passa em sentido horário, pela ordem da mesa que o host arruma na sala.

### 3.2 Ações

| Ação | Efeito | Quem pode bloquear | Espera 5 s? |
|---|---|---|---|
| **Renda** | +1 moeda | ninguém | não |
| **Ajuda Externa** | +2 moedas | qualquer um que diga ter o **Duque** | sim |
| **Golpe de Estado** (7 moedas) | alguém perde uma influência | ninguém | não |
| **Imposto** (Duque) | +3 moedas | ninguém (dá pra desafiar) | sim |
| **Assassinar** (Assassino, 3 moedas) | alguém perde uma influência | o alvo, com a **Condessa** | sim |
| **Extorquir** (Capitão) | pega até 2 moedas do alvo | o alvo, com **Capitão**, **Embaixador** ou **Inquisidor** | sim |
| **Trocar** (Embaixador) | compra 2 do baralho, fica com 2 das 4 e devolve 2 | ninguém (dá pra desafiar) | sim |
| **Trocar** (Inquisidor) | compra 1 do baralho, pode trocar com uma das suas e devolve 1 | ninguém (dá pra desafiar) | sim |
| **Examinar** (Inquisidor) | o alvo mostra uma carta (ele escolhe qual) só pra você; você devolve ou obriga o alvo a trocar essa carta por outra do baralho | ninguém (dá pra desafiar) | sim |

- Com **10 moedas ou mais**, o Golpe de Estado é obrigatório (oficial). O app só mostra essa ação.
- As moedas do Assassinar são pagas na hora e **não voltam** se a ação for bloqueada. Voltam se o assassino perder o desafio (oficial, confirmado no manual).

### 3.3 Desafio

- Quem desafia diz "você não tem esse personagem".
- **Se o desafiado tinha a carta**: ele mostra (o app revela na tela de todo mundo), a carta volta embaralhada para o baralho, ele compra uma nova, e **quem desafiou perde uma influência**. A ação continua.
- **Se não tinha**: o desafiado perde uma influência, e a ação é cancelada.
- **Perder influência**: a pessoa **escolhe qual das suas cartas** vira para cima (oficial). A carta virada fica à mostra para todos até o fim.
- O Assassinar desafiado e perdido pode tirar as duas influências do alvo que desafiou e errou: uma pelo desafio e outra pelo assassinato. É a regra oficial, e o app aplica.

### 3.4 A janela de reação [decidido + proposta nos detalhes]

1. Quem está na vez escolhe a ação (e o alvo). Todas as telas mostram "Ana diz ter o **Duque**: Imposto (+3)".
2. Durante **5 s**, quem pode reagir vê os botões:
   - **"Desafiar"**: qualquer um menos quem fez a ação;
   - **"Bloquear com X"**: só quem pode bloquear essa ação. O bloqueio é uma afirmação, e dá para bloquear blefando.
3. A primeira reação que chega ao host vale. As outras telas mostram "Bia desafiou primeiro".
4. **Bloqueio**: aparece "Bia bloqueia com a Condessa" em todas as telas, com **"Desafiar o bloqueio"** e **"Aceitar"** para todo mundo menos quem bloqueou.
   - O primeiro "Desafiar o bloqueio" que chegar ao host vale.
   - O **"Aceitar" de quem foi bloqueado** encerra: o bloqueio vale e a vez passa.
   - O "Aceitar" dos outros só avisa a mesa ("Caio aceitou") e some da tela dessa pessoa; o jogo continua esperando quem foi bloqueado [proposta].
   - Não tem tempo: fica esperando a decisão de quem foi bloqueado.
5. Ninguém reagiu em 5 s: a ação vale.

Detalhes [proposta]:
- Os 5 s não aparecem como cronômetro, mas os botões vêm com uma barrinha que esvazia, para ninguém ser pego de surpresa.
- Um desafio resolvido e perdido pelo desafiado cancela a ação, então não abre janela de bloqueio. Um desafio perdido pelo desafiante deixa a ação continuar. Quando ainda dá para bloquear (Assassinar, Extorquir, Ajuda Externa), **abre outra janela de 5 s** só para o bloqueio.

### 3.5 Fim

Ganha o último com pelo menos uma influência. Quem saiu vira **espectador**: vê o jogo público, mas não as cartas dos outros [proposta, igual ao Secret Hitler].

## 4. Telas

### 4.1 Celular do jogador (app e navegador)

- **Sala**: ordem da mesa, Embaixador ou Inquisidor, QR (app/navegador) e "Copiar endereço".
- **Minhas cartas**: as 2 cartas com retrato, grandes, com "Esconder" (fica virada até tocar) e o botão fixo "Minhas cartas", como no Avalon. As cartas perdidas aparecem viradas para cima e apagadas.
- **Minha vez**: as ações possíveis como botões grandes, com as moedas.
  - O app avisa quando a ação é blefe ("você não tem o Duque").
  - Quem precisa de alvo abre a lista dos vivos.
  - Com 10 moedas, só aparece o Golpe.
- **Vez dos outros**: a ação anunciada e, se der para reagir, "Desafiar" e "Bloquear com X" com a barrinha de 5 s.
- **Perder influência**: "Escolha a carta que vai virar", com as duas.
- **Trocar e Examinar**: as cartas para escolher, só no seu celular.
- **Mesa**, sempre embaixo: cada jogador com as moedas, as influências (viradas ou não) e de quem é a vez.
- **Histórico curto**: as últimas 5 ações ("Caio pegou 3 com o Duque; ninguém desafiou").

### 4.2 Tabuleiro (app ou navegador, tela grande)

- A mesa grande: cada jogador com moedas e influências, a ação da vez com a barrinha de 5 s, e os desafios e bloqueios aparecendo.
- Quando alguém revela uma carta num desafio, ela aparece grande no tabuleiro.
- **Nunca mostra carta escondida.**

### 4.3 Cuidados para não vazar informação [proposta]

- **Todos veem os botões iguais.** "Bloquear com a Condessa" aparece para o alvo do Assassinar, tenha ele a Condessa ou não. O app nunca desabilita um botão por causa das cartas escondidas.
- O aviso "é blefe" só aparece no celular de quem joga, sem som nem vibração diferente.

## 5. Rede

- Mesma base do Avalon e do Secret Hitler: host autoritativo, app e navegador, estado filtrado. Cada um recebe só as próprias cartas; as cartas examinadas e trocadas só chegam a quem pode ver.
- **Janela de reação**: o host guarda a hora do anúncio e fecha a janela 5 s depois. As reações chegam com a hora acertada pelo `ClockSync` (o mesmo do sino), e vale a mais cedo.
- **Queda no meio**: o jogo espera quem precisa agir (quem está na vez, quem vai perder influência, quem vai trocar). Para as janelas de 5 s, quem caiu simplesmente não reage [proposta].

## 6. Arte

Direção [proposta, minha escolha]: o mesmo guache e nanquim do Avalon, com clima de **corte renascentista italiana**, intrigas de palácio. Cada personagem tem uma cor forte, para ser reconhecido de longe:

| Personagem | Cor |
|---|---|
| Duque | roxo |
| Assassino | preto |
| Capitão | azul |
| Embaixador | verde |
| Inquisidor | laranja |
| Condessa | vermelho |

| Peça | Quem faz |
|---|---|
| Retratos dos 6 personagens (2 ou 3 variações cada, como no Avalon), capa e fundo do tabuleiro | **Nano Banana**, pelos prompts em `docs/coup_prompts.md` |
| Moedas, verso da carta, ícones das ações, barrinha de reação, ícone do jogo | Eu, em SVG |

## 7. Arquitetura

```
games/coup/
├── rules/coup_rules.gd   # puro: baralho, moedas, ações, janela (com horas), desafio, bloqueio, perder influência, 2 jogadores
├── session/              # host com a janela de reação e o relógio acertado; cliente e sessão base
├── screens/              # menu, criar sala, como jogar, jogo (jogador e tabuleiro)
├── ui/                   # carta de personagem, mesa, botões com barrinha
└── art/
web/coup.js
tests/test_coup_rules.gd, tools/coup_bot.gd, tools/coup_net_test.sh
```

As regras recebem a hora do host em cada ação e respondem se a janela ainda está aberta. Assim a janela é testável sem rede. O host tem um `_process` que fecha as janelas vencidas.

## 8. Marcos

| Marco | Entrega | Critério de pronto |
|---|---|---|
| C1 Regras | `CoupRules` + testes | Todas as ações; quem pode bloquear o quê; desafio ganho e perdido (com troca da carta); desafio do bloqueio por qualquer um e o aceitar de quem foi bloqueado; Assassinar com duas perdas; Golpe obrigatório; 2 jogadores; Inquisidor (Trocar e Examinar); janela de 5 s e a primeira reação; eliminação e vitória; filtro do que cada um vê |
| C2 Rede e app | Sessões, telas | Partida inteira com robôs que blefam, desafiam e bloqueiam, conferindo que ninguém recebe carta alheia |
| C3 Navegador | `web/coup.js` | Partida com o navegador no meio dos robôs |
| C4 Arte | Prompts, SVGs, marcadores | Capturas de todas as telas |
| C5 Playtest | Partida real | Ajustar os 5 s e o ritmo |

## 9. Riscos

| Risco | Mitigação |
|---|---|
| **5 s sem "Deixa passar" deixarem o jogo lento** (toda ação espera) | É a sua escolha e dá tempo de pensar. Se o playtest achar lento, dá para ajustar o tempo na sala |
| Desafio e bloqueio quase juntos | Vale o primeiro pelo relógio acertado, e as telas explicam quem foi |
| Vazar informação pelos botões | §4.3: todos veem os mesmos botões |
| Regras intrincadas (Assassinar desafiado, troca depois do desafio) | Testes das regras cobrindo cada caso antes de qualquer tela |
| Nome e arte | Coup é da Indie Boards & Cards/La Mame. App interno; retratos próprios |

## 10. Pendências

| # | Pergunta |
|---|---|
| **P1** | Revisar as **[proposta]**: o "Aceitar" dos outros no bloqueio só avisar (§3.4), barrinha de 5 s e nova janela para bloqueio depois do desafio (§3.4), espectador (§3.5), cuidados (§4.3), queda (§5), direção de arte e cores (§6) |
| **P2** | ~~Moedas do Assassinar quando o assassino perde o desafio~~: confirmado no manual, voltam para ele |

## 11. Status da implementação (2026-09-26)

Feito: C1 a C3, e a arte provisória do C4. Faltam os retratos do Nano Banana e o C5, o playtest.

- **Regras** (`CoupRules`): 13 testes em `tests/test_coup_rules.gd`. Cobrem todas as ações, os bloqueios de cada uma, desafio ganho e perdido (com troca da carta mostrada), desafio do bloqueio por qualquer um, o "Aceitar" dos outros que só avisa, Assassinar com duas perdas, moedas devolvidas no desafio, Golpe obrigatório com 10, 2 jogadores, Inquisidor (Trocar, Examinar e bloquear o Capitão), a janela de 5 s e reação atrasada recusada.
- **Rede**:
  - `CoupHost` e `CoupClient` usam o `PartyClockHost` e o `PartyClockClient` (`games/tema_base/`): o relógio justo do sino, tirado do Quem Foi? para servir aos dois.
  - Desafio e bloqueio vão com a hora do toque, e vale o primeiro.
  - A janela fecha pelo relógio do host. O tempo dela é `config.window_ms`: 5 s na partida, e o teste de rede usa 1,2 s.
- **Teste de rede**: `tools/coup_net_test.sh`, com 3 robôs em redes diferentes, 1 tabuleiro e uma queda, uma partida com o Embaixador e outra com o Inquisidor. Os robôs blefam, desafiam, bloqueiam e aceitam ao acaso e conferem que ninguém recebe carta escondida alheia. O duelo de 2 também foi testado.
- **Telas**: celular do jogador e tabuleiro. Tem ações com aviso de blefe, alvo, a janela com a barrinha, bloqueio, perder carta, troca, examinar, escolha da primeira carta com 2 jogadores, fim e o histórico curto.
- **Navegador**: `web/coup.js` e `web/coup.css`, com o mesmo acerto de relógio. Testado no meio dos robôs: desafio (e desafio atrasado recusado), mostrar carta no exame, perder carta e Extorquir blefando.
- **Arte**: emblemas, moeda, verso e ícone em SVG. Os prompts dos retratos estão em [coup_prompts.md](coup_prompts.md): os 6 personagens com 2 variações cada, a capa e a mesa. As imagens entram sozinhas quando forem salvas em `games/coup/art/`.
