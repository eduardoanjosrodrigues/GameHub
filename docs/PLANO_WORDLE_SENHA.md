# gamehub — Plano do Wordle e do Senha

> Status: v2 · 2026-09-28 · implementado (ver §13); falta testar em aparelho e com pessoas
> Escopo: primeiros jogos **solo** do hub, o **Wordle** (adivinhar a palavra) e o **Senha** (tipo Mastermind). São dois jogos separados, com a mesma base de desafio diário e estatísticas. Os dois também têm modos pelo **Wi-Fi** (app ou navegador).

Legenda (a mesma dos outros planos): **[decidido]** veio das suas respostas; **[proposta]** é sugestão minha (lista em §10); **[verificar]** precisa ser confirmado.

---

## 1. Visão geral

- **Wordle**: descobrir uma palavra de 5 letras. Depois de cada palpite, cada letra fica **verde** (letra certa no lugar certo), **amarela** (a letra existe, mas em outro lugar) ou **cinza** (não existe).
- **Senha**: descobrir uma sequência secreta de pinos (cores ou números). O retorno pode ser **por contagem** (clássico: "2 no lugar certo, 1 no lugar errado", sem dizer quais) ou **por posição** (cada pino colorido, como no Wordle).

Os dois têm **desafio do dia** (igual para todos, vira à meia-noite), **treino ilimitado** e partidas pela rede.

## 2. Decisões [decidido]

| Área | Decisão |
|---|---|
| No hub | **Dois jogos separados**, cada um como um cartão **na lista normal** da tela inicial |
| Nomes | **Wordle** e **Senha** |
| Dia | Vira à **meia-noite no horário do aparelho**. **Não dá para jogar dias passados** |
| Estatísticas | **Tela própria** em cada jogo: jogos, % de vitórias, sequência atual e melhor, e o gráfico de tentativas. As partidas de rede vão para o **Histórico** do app |
| Compartilhar | **Não tem** |
| **Wordle**: modos | **Palavra do dia**, **Treino ilimitado**, **Dueto/Quarteto** (só no treino) e **Corrida no Wi-Fi** |
| **Wordle**: tamanho | **5 letras** |
| **Wordle**: acentos | O teclado não tem acento: digitar CANCAO vale CANÇÃO, e o acento aparece quando as letras são reveladas |
| **Wordle**: respostas | Só **palavras comuns** (lista curada, sem plural nem verbo conjugado). Como palpite, qualquer palavra do dicionário vale |
| **Wordle**: dicionário | Os palpites vêm de uma **lista aberta de pt-BR** (VERO), com crédito no Como jogar. As respostas são **curadas por mim**, e você revisa |
| **Wordle**: palpite inválido | É **recusado**: a linha treme, aparece "palavra não aceita" e não gasta tentativa |
| **Wordle**: modo difícil | **Opcional**: as dicas já reveladas precisam ser usadas nos palpites seguintes |
| **Wordle**: Corrida | Todos tentam **a mesma palavra**. Cabe **só 1 palavra** (sem Dueto/Quarteto) e dá para entrar **pelo navegador** |
| **Senha**: aparência | **Cores ou números**. No solo, o jogador escolhe. Na rede, **o host escolhe para todos** |
| **Senha**: retorno | **Contagem ou por posição**. No solo, o jogador escolhe. Na rede, o host escolhe |
| **Senha**: níveis | **Fácil**: 4 pinos, 6 símbolos, sem repetição. **Médio**: 4 pinos, 6 símbolos, com repetição. **Difícil**: 5 pinos, 8 símbolos, com repetição. Sempre **10 tentativas** |
| **Senha**: modos | **Senha do dia**, **Treino ilimitado**, **Duelo no Wi-Fi** e **Corrida no Wi-Fi** |
| **Senha**: do dia | **Uma senha por nível** (Fácil, Médio e Difícil do dia), cada uma com sua sequência |
| **Senha**: Duelo | 1 contra 1, e cada um cria a senha do outro. O host escolhe entre **alternado** (um palpite por vez; se quem começou quebra a senha, o outro tem a **última chance** naquela rodada, e se os dois acertarem empata) e **modo tempo** (os dois ao mesmo tempo, e **vence quem quebrar primeiro**, pelo relógio sincronizado) |
| Corrida (os dois jogos) | O **host escolhe o critério**: **menos tentativas** (o tempo desempata), **primeiro a acertar** (os outros **continuam** jogando para decidir as posições seguintes) ou **pontos em N rodadas** |
| Corrida: tempo | O host escolhe **sem limite, 2, 3 ou 5 min**. Quando o tempo acaba, quem não acertou perde a rodada |
| Corrida: andamento | Cada um vê **mini-grades dos adversários só com as cores**, sem as letras nem os símbolos |

## 3. Regras do Wordle

### 3.1 Cores (regra padrão do Wordle, com letras repetidas)

1. Primeiro, as letras no lugar certo ficam **verdes**.
2. Depois, da esquerda para a direita, cada letra restante fica **amarela** enquanto a resposta ainda tiver cópias dessa letra que não foram usadas. As outras ficam **cinza**.
   Exemplo: resposta **CARTA**, palpite **AAAAA** → a 2ª e a 5ª letras ficam verdes, e as outras cinza.
3. A comparação ignora acento e cedilha: A = Á = Â = Ã = À, C = Ç etc. [decidido]
4. O teclado na tela pinta cada tecla com a melhor cor que ela já teve (verde > amarela > cinza).

### 3.2 Modos

| Modo | Palavras | Tentativas | Conta sequência? |
|---|---|---|---|
| Palavra do dia | 1 | 6 | Sim |
| Treino | 1 | 6 | Não (tem estatística própria) [proposta] |
| Dueto (treino) | 2 | 7 | Não |
| Quarteto (treino) | 4 | 9 | Não |

- No Dueto e no Quarteto, cada palpite vale para todas as grades. Uma grade para de receber palpites quando é resolvida. Você vence se resolver todas. As palavras de uma partida são **diferentes entre si** [proposta].
- O teclado do Dueto/Quarteto divide cada tecla em 2 ou 4 partes, uma cor por grade (como o Termo) [proposta].
- Se você sair no meio da palavra do dia, a partida **continua de onde parou** ao voltar no mesmo dia [proposta]. Se não terminar até a meia-noite, conta como derrota e a sequência zera [proposta].

### 3.3 Modo difícil [decidido: opcional]

- As letras verdes precisam estar **no mesmo lugar** nos próximos palpites, e as amarelas precisam **aparecer** em algum lugar. Quando um palpite quebra a regra, o app recusa e avisa qual letra falta ("A 2ª letra precisa ser A").
- Fica numa chave dentro do jogo. Só pode ser ligado ou desligado **antes do primeiro palpite** da partida [proposta].
- Na Corrida, é **o host que decide** se vale para todos [proposta].

### 3.4 Palavra do dia

- A lista de respostas é embaralhada **uma vez só**, com uma semente fixa, e fica no app. O dia N usa a palavra N da lista, contando a partir da data de lançamento [proposta]. Assim todos os aparelhos têm a mesma palavra e nenhuma se repete até a lista acabar. Com as 987 respostas, isso dá uns 2 anos e 8 meses.
- O treino sorteia qualquer palavra da lista de respostas, mas **evita as palavras do dia já passadas e as dos próximos 30 dias** [proposta], para não estragar o diário.
- Mudar o relógio do aparelho permite "adiantar" o dia. Não vou tentar impedir isso [proposta].

## 4. Regras do Senha

### 4.1 Símbolos

- **Cores**: 8 cores bem distintas. Cada uma também tem um **símbolo** (●, ▲, ■, ◆...), para quem é daltônico [proposta]. Os níveis de 6 símbolos usam as 6 primeiras.
- **Números**: os dígitos de 1 a 6 (ou de 1 a 8) [proposta: começar do 1 para bater com as cores].
- A aparência não muda as regras: a senha "3-1-4-1" em números é a mesma senha que "verde-vermelho-azul-vermelho" em cores.

### 4.2 Retorno

- **Contagem (clássico)**: aparecem **●** para cada pino certo no lugar certo e **○** para cada pino certo no lugar errado, sem ordem e sem dizer quais. Com repetições, a conta é a mesma do Mastermind: cada pino da senha só pode ser contado uma vez.
- **Por posição**: cada pino do palpite fica verde, amarelo ou cinza, com a mesma regra de repetição do Wordle (§3.1).
- No Fácil (sem repetição), o app **não deixa montar um palpite com símbolo repetido** [proposta].

### 4.3 Solo

- **Senha do dia**: há três por dia (Fácil, Médio e Difícil), cada uma com sua sequência e sua estatística. O retorno e a aparência são **escolha do jogador** e podem mudar sem afetar a sequência, porque a senha é a mesma [proposta]. A senha é gerada a partir de **dia + nível** com um sorteio fixo, igual em todos os aparelhos.
- **Treino**: o jogador escolhe o nível, o retorno e a aparência, e a senha é aleatória.
- Se sair no meio, a partida continua de onde parou, como no Wordle [proposta].

### 4.4 Duelo (Wi-Fi, 2 jogadores)

1. O host escolhe o **nível**, o **retorno**, a **aparência** e o **tipo** (alternado ou tempo).
2. Cada um **cria uma senha** seguindo o nível (sem repetição no Fácil). O outro nunca vê a senha até o fim.
3. **Alternado**: quem começa é sorteado [proposta]. Cada um faz um palpite na senha do outro, na sua vez. Quem cria a senha vê ao vivo os palpites feitos contra ela [proposta]. Se quem começou quebrar a senha, o outro ainda faz o palpite daquela rodada: se acertar, empata. Se ninguém quebrar em 10 tentativas, **empata** [proposta].
4. **Modo tempo**: os dois atacam ao mesmo tempo, e vence quem quebrar primeiro, pelo relógio sincronizado (como no Halli Galli). Se ninguém quebrar em 10 tentativas, empata [proposta]. O limite de tempo da Corrida também pode valer aqui, e se o tempo acabar é empate [proposta].
5. No fim, as duas senhas aparecem, e tem botão de **revanche**.

### 4.5 Corrida (Wi-Fi)

É igual à Corrida do Wordle (§5), com uma senha sorteada pelo app no nível, no retorno e na aparência que o host escolheu.

## 5. Corrida (Wordle e Senha)

- De **2 a 12 jogadores** [proposta]. O host joga também. Quem joga pelo navegador entra pelo QR code.
- O host escolhe o **critério**, o **tempo limite** e o **modo difícil** (só no Wordle).
- Todos começam juntos com uma **contagem 3-2-1**. O tempo de cada um vem do relógio sincronizado (`net/clock_sync.gd`).
- **Critérios**:
  - **Menos tentativas**: a classificação é por número de tentativas e, se empatar, por tempo. A rodada acaba quando todos acertarem, errarem tudo ou o tempo acabar.
  - **Primeiro a acertar**: a classificação é pela ordem de chegada, e os outros continuam jogando. Quem não acerta fica atrás, ordenado pelo melhor palpite (mais verdes e depois mais amarelas) [proposta].
  - **Pontos em N rodadas**: o host escolhe N entre 3, 5 e 10 [proposta]. Em cada rodada, quem acerta ganha **(tentativas máximas + 1 − tentativas usadas)** pontos, mais um bônus de chegada de **3/2/1** para 1º/2º/3º [proposta]. Quem erra fica com 0. No fim aparece o placar, e um empate é decidido pela soma dos tempos [proposta].
- **Mini-grades** dos adversários: mostram só as cores dos palpites, ao vivo, com o nome e um ✓ quando a pessoa acerta.
- No fim de cada rodada, todos veem a resposta, as grades completas de todo mundo e a classificação.
- Quem cai da rede pode voltar (como nos outros jogos) e continua a sua grade. Quem chega no meio **espera a próxima rodada** [proposta].

## 6. Telas

- **Menu do jogo**: Do dia · Treino · Jogar no Wi-Fi · Estatísticas · Como jogar. No menu do Wordle, o Dueto e o Quarteto ficam dentro de Treino. No Senha, o dia mostra os três níveis, com ✓ nos que já foram jogados.
- **Partida (Wordle)**: a grade em cima e o teclado QWERTY em baixo, com ENTER e ⌫ [proposta: QWERTY, como no Termo]. As letras são reveladas uma por uma com animação de virar, e a linha treme quando o palpite é recusado. Em tablet, a grade fica maior e centralizada.
- **Partida (Senha)**: as linhas de palpite com o retorno ao lado, e em baixo uma paleta de símbolos para tocar e preencher. Dá para tocar num pino já colocado para apagar.
- **Fim**: a resposta, o resultado e um atalho para as estatísticas. No diário aparece a contagem até a próxima palavra; no treino, o botão "Jogar de novo".
- **Estatísticas**: são separadas por modo: Wordle do dia, treino, Dueto e Quarteto; Senha do dia por nível e treino [proposta].
- **Sala Wi-Fi**: a sala de sempre (código, QR e lista de jogadores) mais as opções do host.
- O visual é escolha minha e segue os outros jogos (tokens do app). Eu mostro capturas para você aprovar.

## 7. Palavras

- **Palpites válidos**: as 20.318 palavras de 5 letras do **VERO** (o dicionário ortográfico do LibreOffice, licença LGPLv3 ou MPL, conferida no README dele), expandido com as flexões: plurais, femininos e verbos conjugados entram. A comparação é sem acento. O crédito está no rodapé do Como jogar do Wordle.
- **Respostas**: **987** palavras comuns (substantivos e adjetivos no singular, sem nomes próprios, palavrões ou termos ofensivos), escolhidas à mão entre as formas de 5 letras mais frequentes. Isso dá uns 2 anos e 8 meses de palavra do dia; depois, a lista recomeça. `tools/build_wordle_words.py` gera a lista de palpites e confere as respostas. **Você revisa a lista de respostas** (`games/wordle/data/respostas.txt`) antes do lançamento.
- Toda resposta precisa também estar na lista de palpites (há um teste para isso).

## 8. Rede

- Reaproveita a base dos outros jogos: `PartyHost`/`PartyClient` e `PartyClockHost`/`PartyClockClient` em `games/tema_base`, a sala, o QR e o navegador (`net/web_gateway.gd`).
- **Só o host sabe a resposta.** Quem joga manda o palpite, o host confere no dicionário, calcula as cores e devolve. Assim a resposta nunca chega ao JavaScript do navegador, e os jogadores do navegador não precisam baixar o dicionário. Na rede local isso é rápido o bastante [proposta].
- No Duelo, cada senha fica guardada só no host, e o host é quem calcula o retorno.
- O host manda para os outros apenas as **cores** de cada palpite (para as mini-grades), nunca as letras.
- Web: `web/wordle.js` e `web/senha.js`.

## 9. Arquitetura

- `games/wordle/` e `games/senha/`, cada um com `rules/` (lógica pura, `RefCounted`, testável), `screens/` e `data/`.
- Base comum para os dois: `games/desafio_base/`, com o desafio do dia (índice do dia, sorteio fixo), a gravação da partida em andamento e das estatísticas em `user://`, e a tela de estatísticas [proposta].
- Testes em `tests/`: cores com letras repetidas, retorno do Senha com repetição, modo difícil, índice do dia na virada da meia-noite, respostas ⊂ palpites e protocolo de rede (`tools/party_net_test.sh wordle|senha` ou equivalente).

## 10. Propostas (aprovadas junto com o pedido de implementação)

1. Treino, Dueto e Quarteto têm estatísticas próprias, sem sequência (§3.2, §6).
2. As palavras do Dueto/Quarteto são diferentes entre si, e o teclado é dividido por grade (§3.2).
3. A partida do dia continua de onde parou. Se não terminar até a meia-noite, conta como derrota (§3.2, §4.3).
4. O modo difícil só muda antes do 1º palpite. Na Corrida, o host decide (§3.3).
5. A palavra do dia sai de uma lista embaralhada fixa, e o treino evita as palavras do dia já passadas e as dos próximos 30 dias (§3.4).
6. Não vou tentar impedir quem mudar o relógio do aparelho (§3.4).
7. Cada cor tem um símbolo para quem é daltônico, e os números vão de 1 a 6/8 (§4.1).
8. No Fácil, o app não deixa repetir símbolo no palpite (§4.2).
9. Na Senha do dia, dá para mudar o retorno e a aparência sem afetar a sequência (§4.3).
10. No Duelo: quem começa é sorteado, quem criou a senha vê os ataques ao vivo, e se ninguém quebrar é empate (§4.4).
11. A Corrida aceita de 2 a 12 jogadores, e quem chega no meio espera a próxima rodada (§5).
12. No "Primeiro a acertar", quem não acerta é ordenado pelo melhor palpite (§5).
13. A pontuação das N rodadas é (máx + 1 − usadas) + bônus de 3/2/1, com N entre 3, 5 e 10 e desempate por tempo (§5).
14. O teclado é QWERTY (§6).
15. As respostas só chegam aos jogadores no fim, porque o host é quem confere (§8).

## 11. Riscos

- **Nome "Wordle"**: é marca do New York Times. Você autorizou usar o nome, mas isso pode dar problema na Play Store (é a mesma questão do Halli Galli, pendência P1).
- **Mudança na lista de respostas depois do lançamento**: a palavra de cada dia depende da lista inteira (embaralhada com semente fixa). Trocar uma palavra por outra na mesma linha é seguro; apagar ou incluir muda as palavras dos dias seguintes.
- **Qualidade do dicionário**: palavras válidas que faltam irritam o jogador ("minha palavra não foi aceita!"). É preciso testar a lista com gente.
- **Tamanho do APK**: uma lista de 5 letras é pequena (dezenas de milhares × 6 bytes ≈ algumas centenas de KB).

## 12. Marcos

1. Base do desafio do dia e das estatísticas, com testes.
2. Wordle solo: dia, treino e modo difícil, com o script das listas.
3. Dueto e Quarteto.
4. Senha solo: dia por nível e treino.
5. Corrida (os dois jogos), no app e no navegador.
6. Duelo do Senha.
7. Capturas para você aprovar e revisão da lista de respostas.

## 13. Status da implementação (2026-09-28)

Feito: marcos 1 a 7. Falta testar num celular de verdade e com pessoas, e você revisar a lista de respostas.

- **Base comum** (`games/desafio_base/`):
  - `Desafio`: número do dia pela data local, embaralhamento fixo e as cores por posição (regra de repetidas do Wordle);
  - `DesafioStore`: estatísticas, partidas em andamento e preferências em `user://desafios.json`. A partida do dia que não terminou até a meia-noite vira derrota;
  - `DesafioStatsScreen`: tela de estatísticas;
  - `RaceRules` e `DesafioNetScreen`: a Corrida pela rede (contagem, mini-grades só com as cores, resultado e placar).
- **Wordle** (`games/wordle/`): palavra do dia, treino, Dueto e Quarteto, modo difícil e Corrida no Wi-Fi. A grade e o teclado são desenhados em código (`ui/`), com a letra virando ao revelar e a linha tremendo no palpite recusado.
- **Senha** (`games/senha/`): senha do dia por nível, treino, retorno por contagem ou por posição, cores (com forma pra daltônicos) ou números, Duelo (alternado ou modo tempo) e Corrida no Wi-Fi.
- **Navegador**: `web/desafio.js`, `web/wordle.js`, `web/senha.js` e `web/desafio.css`, testados no navegador contra um host de verdade (Corrida do Wordle e Duelo do Senha).
- **Testes**: 25 testes novos em `tests/test_wordle_senha.gd` e `tests/test_desafio_net.gd`. A rede é testada com robôs em `tools/desafio_net_test.sh wordle|senha [corrida|duelo] [tentativas|primeiro|pontos]`: um robô cai no meio e volta, e cada robô confere que o segredo e as letras dos outros não chegam antes da hora.
- **Capturas**: `godot -- --tour=/pasta --tour-set=desafio --tour-size=720x1280`.
- **Tela inicial**: os jogos aparecem do aberto mais recentemente (pelo botão Jogar ou ao entrar numa sala) para o mais antigo; os nunca abertos vêm depois, em ordem alfabética. A data fica em `Settings.last_played`.
