# gamehub — Plano do Quem Foi?

> Status: v1 · 2026-09-26 · plano, nada implementado
> Escopo: sétimo jogo do hub, **Quem Foi?** (versão brasileira da PaperGames do *Who Did It?*, da Blue Orange). Pelo **Wi-Fi**, cada um no seu celular (app ou navegador), com **tabuleiro opcional**. Usa a corrida justa do sino do Halli Galli.

Legenda (a mesma dos outros planos): **[decidido]** veio das suas respostas; **[proposta]** é sugestão minha (lista em §10); **[verificar]** precisa ser confirmado.

Regras tiradas do manual oficial da Blue Orange (inglês, 2018): [WHO-DID-IT_rules_UK.pdf](https://blueorangegames.eu/wp-content/uploads/2018/05/WHO-DID-IT_rules_UK.pdf).

---

## 1. Visão geral

Acharam um cocô enorme no meio da sala, e foi o bicho de alguém. Cada pessoa tem 6 bichos da sua cor: **papagaio, peixe, tartaruga, coelho, gato e hamster**. Quem joga um bicho diz "não foi o meu gato, acho que foi o coelho de alguém". Quem tem coelho corre para jogar o seu primeiro, prova que é inocente e acusa outro bicho. Quem fica com a culpa leva um cocô.

É um jogo de **reflexo** (achar a carta e jogar antes dos outros) e de **memória** (lembrar quais bichos já saíram, para não acusar um que ninguém mais tem).

## 2. Decisões [decidido]

| Área | Decisão |
|---|---|
| Aparelhos | **Igual ao Halli Galli em rede**: cada um no seu celular, pelo app ou pelo navegador. A corrida usa o mesmo acerto de relógio do sino, para ser justa. **Tabuleiro opcional**, com a pilha e os cocôs |
| Jogadores | **3 a 6** (6 cores), como o oficial |
| A mão na corrida | **Embaralha a cada acusação**: os bichos que a pessoa ainda tem trocam de lugar na tela. É preciso achar o certo; **tocar no errado trava por 1 segundo** |
| Acusação | Quem ganhou a corrida **toca num dos 6 bichos**, sem limite de tempo. Vale qualquer bicho, até o mesmo que acabou de jogar |
| Memória | A mesa mostra **só a carta do topo**, como a pilha de verdade. Na sala dá para ligar uma **"ajuda de memória"** (quantos de cada bicho já saíram), para jogar com criança |
| Ninguém tem o bicho | **5 segundos de suspense**, com todo mundo procurando. Depois aparece o culpado e a mão de todos como prova |
| Quem começa | Na 1ª rodada, sorteado; depois, **quem levou o cocô** |
| Fim | Com **3 cocôs** (oficial). O host pode escolher de 2 a 5 na sala |
| Arte | Os 6 bichos e a capa pelo **Nano Banana**, com prompts meus. Os textos e as cores de cada jogador ficam por conta do app |

## 3. Regras (oficiais, com o que o app decide)

1. **Começo**: cada um recebe os 6 bichos da sua cor. A pilha começa vazia, com o cocô no meio.
2. **Primeira jogada**: quem começa joga um bicho e acusa outro bicho (pode ser do mesmo tipo: "não foi o meu gato, foi o gato de outra pessoa").
3. **Corrida**: **todos menos quem acusou** (oficial: quem acusou não pode jogar nessa vez) correm para jogar o bicho acusado. Só conta quem ainda tem esse bicho. O primeiro a chegar ao host ganha, pelo relógio acertado como no Halli Galli.
4. Quem ganhou a corrida põe a carta no topo da pilha e **acusa o próximo bicho**. E assim segue.
5. **Mão vazia**: quem joga a última carta e passa a culpa adiante está a salvo e **sai da rodada**; todos os seus bichos são inocentes (oficial).
6. **Fim da rodada** (oficial), de duas formas:
   - **Ninguém mais tem o bicho acusado**: o culpado é o bicho que acabou de ser jogado, e o **dono dele leva o cocô**. O app espera 5 s de suspense [decidido], mostra "Ninguém tem mais coelho!" e abre a mão de todo mundo como prova.
   - **Só uma pessoa ainda tem cartas**: ela leva o cocô, porque não tem mais ninguém para quem passar a culpa.
7. **Nova rodada**: todos pegam os 6 bichos de volta. Quem levou o cocô começa [decidido].
8. **Fim da partida**: quando alguém chega a 3 cocôs (ou ao número da sala). Ganha quem tiver **menos**, e empate divide a vitória (oficial).

Casos que o app resolve sozinho [proposta]:
- **Tocar no bicho errado** durante a corrida: fica 1 s travado [decidido], com a tela tremendo. Não perde a carta.
- **Tocar sem ter o bicho**: não existe, porque a pessoa só vê os bichos que ainda tem.
- **Corrida com uma pessoa só** (só ela tem o bicho acusado): ela ainda precisa achar e tocar. Não é automático, para não entregar que só ela tem.
- **Queda no meio**: quem caiu sai da corrida enquanto estiver fora. Se cair justo quem vai acusar, o jogo espera a pessoa (ou a troca de aparelho).

## 4. Telas

### 4.1 Celular do jogador (app e navegador)

- **Sala**: lista de quem entrou, com a cor de cada um; limite de cocôs; ajuda de memória; QR (app/navegador) e "Copiar endereço".
- **Topo, sempre**: a carta do topo da pilha, grande, com o bicho e a cor do dono; a frase da vez ("Não foi o meu gato… acho que foi o **COELHO** de alguém!"); os cocôs de cada um.
- **A mão**: os bichos que você ainda tem, grandes, em posições novas a cada acusação.
  - Na corrida, você toca no bicho acusado.
  - Quando é você quem acusa, os seus aparecem apagados e surgem os 6 bichos para escolher o próximo.
  - Quem já zerou a mão vê "Seus bichos são inocentes! Agora é só assistir".
- **Resultado da rodada**: quem levou o cocô, por quê, e as mãos de todos.
- **Fim**: ranking pelos cocôs e "Jogar de novo".

### 4.2 Tabuleiro (app ou navegador, tela grande)

- A pilha com a carta do topo bem grande, a frase da vez, os cocôs de cada um e quantas cartas cada um ainda tem.
- **Não mostra** a mão de ninguém nem o que já saiu, a não ser com a ajuda de memória ligada.
- Na corrida, pisca o nome de quem ganhou.

### 4.3 Som e vibração [proposta]

- Acusação: um "pum" de desenho animado e uma vibração curta em todos os celulares, a mesma para todo mundo.
- Ganhou a corrida: um "plim". Tocou no errado: um "bzz" e a vibração de erro do Halli Galli.
- Culpado: descarga de privada. O fim da partida toca a mesma música de vitória dos outros jogos.

## 5. Rede

- Mesma base dos outros jogos: host autoritativo, app (ENet) e navegador (WebSocket), estado filtrado por quem vê. Cada um recebe só a própria mão; o tabuleiro não recebe nenhuma.
- **Corrida justa**: igual ao sino do Halli Galli. Cada toque vai com a hora do aparelho acertada pelo `ClockSync`, e o host espera uma janela curta antes de decidir quem chegou primeiro, para compensar quem tem a rede mais lenta [proposta: a mesma janela do sino].
- Troca de aparelho funciona como nos outros jogos.

## 6. Arte

Direção [proposta]: o mesmo estilo de guache e nanquim sobre papel creme do Avalon, só que **fofo e bobo**. Os bichos fazem cara de inocente, com um toque de culpa.

| Peça | Quem faz |
|---|---|
| 6 bichos (papagaio, peixe no aquário, tartaruga, coelho, gato, hamster), capa (16:9) e o cocô | **Nano Banana**, pelos prompts que eu escrevo em `docs/quem_foi_prompts.md` |
| Cor do jogador (moldura e coleira desenhadas por cima), cartas, textos, ícones de cocô e ícone do jogo no hub | Eu, em SVG e no app |

A mesma imagem de cada bicho serve para as 6 cores: o app pinta a moldura e um lenço ou coleira na cor do dono. Assim são só 6 imagens em vez de 36 [proposta].

## 7. Arquitetura

```
games/quem_foi/
├── rules/quem_foi_rules.gd  # puro: mãos, pilha, acusação, corrida (com hora do relógio), fim de rodada, placar
├── session/                 # host com a janela de corrida justa (como o halli_host); cliente e sessão base
├── screens/                 # menu, criar sala, como jogar, jogo (jogador e tabuleiro)
├── ui/                      # carta do bicho com a cor, mão embaralhada, pilha
└── art/                     # imagens do Nano Banana (WebP, originais em art_originais/)
web/quem_foi.js
tests/test_quem_foi_rules.gd, tools/quem_foi_bot.gd, tools/quem_foi_net_test.sh
```

Reaproveitamento [proposta]:
- O `PartyClient` e o `PartyGameScreen` da Sintonia/Ito servem direto.
- O host precisa da janela de corrida do Halli Galli. Vou tirar essa parte do `halli_host` para uma peça comum, sem mudar o comportamento do Halli Galli; o teste de justiça do sino continua sendo a prova.

## 8. Marcos

| Marco | Entrega | Critério de pronto |
|---|---|---|
| Q1 Regras | `QuemFoiRules` + testes | Corrida; quem acusou não joga; mão vazia sai da rodada; os dois fins de rodada; quem começa; limite de cocôs; empate; filtro do que cada um vê |
| Q2 Rede e app | Sessões, telas, corrida justa | Partida inteira com robôs de redes diferentes, e quem tem a pior rede e toca primeiro ganha |
| Q3 Navegador | `web/quem_foi.js` | Partida com o navegador no meio dos robôs |
| Q4 Arte | Prompts, SVGs, marcadores | Capturas de todas as telas |
| Q5 Playtest | Partida real | Lista de ajustes resolvida |

## 9. Riscos

| Risco | Mitigação |
|---|---|
| Corrida injusta no Wi-Fi | O mesmo mecanismo do sino, que já tem teste com atrasos diferentes |
| Mão embaralhada frustrante | Bichos grandes e cores fortes; se o playtest achar difícil demais, dá para desligar na sala |
| Os 5 s de suspense entregam que ninguém tem | Durante os 5 s todos veem a mesma tela de corrida; ninguém sabe se é suspense ou se o outro está demorando |
| Nome e marca | "Quem Foi?" é da PaperGames e "Who Did It?" da Blue Orange. Uso interno; para a loja, trocar o nome |

## 10. Pendências

| # | Pergunta |
|---|---|
| **P1** | Revisar as **[proposta]**: casos do §3, som e vibração (§4.3), janela da corrida (§5), direção de arte e 6 imagens em vez de 36 (§6), tirar a corrida do Halli Galli para uma peça comum (§7) |
