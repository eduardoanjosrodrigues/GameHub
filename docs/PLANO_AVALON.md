# gamehub — Plano do Avalon

> Status: v3 · 2026-09-26 · implementado, com toda a arte (ver §11); falta testar com pessoas
> Escopo: terceiro jogo do hub, **Avalon** (A Resistência: Avalon), pelo **Wi-Fi** (app ou navegador), com **tabuleiro opcional**.

Legenda (a mesma dos outros planos): **[decidido]** veio das suas respostas; **[proposta]** é sugestão minha (lista em §10); **[verificar]** precisa ser confirmado.

---

## 1. Visão geral

Jogo de papéis secretos, de 5 a 10 pessoas. Os **servos leais de Arthur** (bem) tentam completar 3 missões; os **lacaios de Mordred** (mal) tentam sabotar 3 missões. A cada rodada um líder escolhe o time da missão, todos votam o time e, se aprovado, quem está no time joga Sucesso ou Falha em segredo.

O app substitui o "todo mundo fecha o olho" (cada celular mostra o papel e o que a pessoa sabe), a votação (secreta, revelada junto) e as cartas de missão (secretas, embaralhadas). A conversa continua na mesa.

## 2. Decisões [decidido]

| Área | Decisão |
|---|---|
| Nome e tema | Originais do Avalon, em português (app interno) |
| Modos | Wi-Fi: cada um no seu celular, pelo **app** (Android) ou pelo **navegador** (iPhone), como os outros jogos |
| Tabuleiro | **Opcional**, como no Chapéu: quem cria a sala escolhe se joga ou se é o tabuleiro; outro aparelho também pode entrar como tabuleiro, **pelo app ou pelo navegador** (TV, notebook) |
| Jogadores | **5 a 10** (tabela oficial) |
| Personagens | Todos disponíveis: Merlin, Assassino, Percival, Morgana, Mordred, Oberon e Dama do Lago. **O host escolhe quais entram**; Merlin e Assassino vêm ligados por padrão |
| Voto do time | No celular, secreto, **revelado todo mundo junto** |
| Carta de missão | Todos veem Sucesso e Falha; pro **bem, a Falha fica desabilitada** e, se tocar nela, o app explica que é contra as regras |
| 5 recusas seguidas | **Os maus vencem** (oficial) |
| Líder | **Ordem da mesa**, o host arruma na sala; o primeiro líder é sorteado; a liderança passa em sentido horário |
| Cronômetro | **Opcional, o host liga** (1 a 5 min) pra discussão antes do líder fechar o time; é só um aviso |

## 3. Regras

### 3.1 Tabela oficial

| Jogadores | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|
| Bem / Mal | 3/2 | 4/2 | 4/3 | 5/3 | 6/3 | 6/4 |
| Missão 1 | 2 | 2 | 2 | 3 | 3 | 3 |
| Missão 2 | 3 | 3 | 3 | 4 | 4 | 4 |
| Missão 3 | 2 | 4 | 3 | 4 | 4 | 4 |
| Missão 4 | 3 | 3 | 4* | 5* | 5* | 5* |
| Missão 5 | 3 | 4 | 4 | 5 | 5 | 5 |

\* Com 7 ou mais jogadores, a missão 4 só falha com **2 Falhas**.

### 3.2 Personagens e o que cada um sabe

| Personagem | Lado | Vê no começo |
|---|---|---|
| Servo leal de Arthur | Bem | Nada |
| **Merlin** | Bem | Quem é do mal, **menos Mordred** (vê Oberon) |
| **Percival** | Bem | Merlin e Morgana, sem saber quem é quem |
| Lacaio de Mordred | Mal | Os outros do mal, **menos Oberon** |
| **Assassino** | Mal | Idem. No fim, se o bem vencer as missões, tenta adivinhar Merlin |
| **Morgana** | Mal | Idem. Aparece pro Percival como se fosse Merlin |
| **Mordred** | Mal | Idem. Merlin não vê Mordred |
| **Oberon** | Mal | **Ninguém**, e os outros do mal não veem Oberon |

Validação da escolha do host [proposta]: Assassino entra sempre que Merlin entra (e sai junto); Percival precisa de Merlin; Morgana precisa de Percival; os personagens do mal escolhidos não podem passar do número de maus da tabela. O resto das vagas vira servo leal ou lacaio.

### 3.3 Uma rodada

1. **Montar o time**: o líder escolhe no celular quantas pessoas a missão pede (pode se incluir). Todo mundo vê a escolha ao vivo. Se o cronômetro estiver ligado, ele corre aqui.
2. **Votar o time**: todos votam Aprovar ou Rejeitar. Aparece quem já votou (não o voto). Quando o último vota, os votos aparecem todos juntos.
   - Maioria de Aprovar (mais da metade): vai pra missão.
   - Empate ou maioria de Rejeitar: a liderança passa pro próximo e o contador de recusas sobe. **Na 5ª recusa seguida, o mal vence.** O contador zera quando um time é aprovado.
3. **Missão**: só quem está no time escolhe Sucesso ou Falha, em segredo. Quando todos jogaram, o app mostra as cartas embaralhadas: quantas Falhas saíram, sem dizer de quem.
4. A liderança passa pro próximo e começa a próxima missão.

### 3.4 Dama do Lago (se o host ligar, só com 7 ou mais)

- Começa com quem está à direita do primeiro líder (o anterior na ordem da mesa).
- Depois das missões 2, 3 e 4, quem tem a Dama escolhe alguém que ainda não teve a Dama e vê, só no próprio celular, se essa pessoa é do bem ou do mal. A Dama passa pra pessoa examinada.

### 3.5 Fim

- **3 missões falhadas**: o mal vence.
- **5 recusas seguidas**: o mal vence.
- **3 missões com sucesso**: se Merlin está no jogo, vem o **assassinato**. Os maus se revelam entre si (no celular deles aparece todo o time do mal, inclusive Oberon), conversam e o Assassino aponta quem acha que é Merlin. Acertou, o mal vence; errou, o bem vence. Sem Merlin, o bem vence direto.
- No fim, todos os papéis aparecem pra todo mundo.

## 4. Telas

### 4.1 Celular do jogador (app e navegador)

- **Sala**: ordem da mesa (host arruma), personagens escolhidos, Dama, cronômetro, QR (app/navegador) e "Copiar endereço" (host).
- **Seu papel**: carta com a arte do personagem e o que ele sabe ("Estes são do mal: Ana, Caio"). Botão "Esconder" deixa a carta virada; tocar de novo mostra. Botão "Pronto" (a partida segue quando todos marcam pronto) [proposta].
- **Durante o jogo**: um botão fixo **"Meu papel"** pra espiar de novo a qualquer momento [proposta].
- **Montar o time**: líder vê a lista com caixinhas e "Enviar pra votação"; os outros veem a escolha ao vivo e "Ana está escolhendo o time".
- **Votar**: dois botões grandes, Aprovar e Rejeitar. Depois do voto: "Você votou: Aprovar" e quem falta votar.
- **Resultado do voto**: lista com o voto de cada um, aprovado ou rejeitado.
- **Missão**: quem está no time vê Sucesso e Falha (Falha desabilitada pro bem, com explicação ao tocar). Os outros veem "Esperando o time da missão".
- **Resultado da missão**: as cartas viram uma a uma, embaralhadas.
- **Dama do Lago**, **assassinato** e **fim**, conforme §3.
- Placar sempre visível no topo: as 5 missões (tamanho, resultado), contador de recusas e o líder.

### 4.2 Tabuleiro (app ou navegador, tela grande)

- Na sala: QR grande, lista de quem entrou.
- No jogo: a trilha das 5 missões (com o tamanho e o "2 falhas" da 4ª), a trilha de recusas, quem é o líder, o time proposto, quem já votou, os votos revelados, as cartas da missão virando, quem tem a Dama. **Nunca mostra nada secreto.**
- O tabuleiro e o host podem apertar "Continuar" depois de cada resultado; o líder da vez também [proposta].

## 5. Rede

- Mesmo desenho do Chapéu e do Halli Galli: host autoritativo, `Net` (ENet) pro app e `WebGateway` pro navegador, estado filtrado por quem está vendo (cada um só recebe o próprio papel e o que ele sabe; o tabuleiro não recebe papel nenhum até o fim).
- Descoberta, QR e código iguais; a sala some da descoberta quando a partida começa; quem cai volta pelo id do aparelho.
- Queda no meio: **o jogo espera** [proposta]. Quem caiu aparece como desconectado; se for a vez dele (líder, voto ou missão), todo mundo espera ele voltar. Não tem remover jogador no meio (quebraria as contas de papéis).
- **Trocar aparelho** [decidido] (vale pra Avalon, Chapéu e Halli Galli; `net/seat_transfer.gd`): se a bateria de alguém acaba ou o celular trava, o **host ou o tabuleiro** abre "Trocar aparelho", escolhe a pessoa e mostra um QR que só serve pra vaga dela (uso único, 5 minutos; navegador ou app). O aparelho que ler entra no lugar dela, com o mesmo papel e o mesmo estado; no Avalon a carta chega virada. Dá pra trocar quem caiu ou, com confirmação, quem ainda está conectado (celular travado). O aparelho antigo **perde a vaga**: se voltar, vê "Seu lugar foi passado para outro aparelho". A vaga do host não troca (é ele que roda a partida). Quando alguém cai, o host e o tabuleiro veem "Fulano caiu · Trocar aparelho".

## 6. Arte

Direção [proposta, minha escolha]: **ilustração de livro de contos em guache e nanquim sobre papel creme**, na paleta do hub (cobalto, tomate, mostarda, sálvia e tinta quase preta), com o bem puxando pro cobalto e o mal pro tomate. Nada de pixel art.

| Peça | Quem faz |
|---|---|
| Retratos dos personagens (Merlin, Percival, Servo leal ×3 variações, Assassino, Morgana, Mordred, Oberon, Lacaio ×3 variações), Dama do Lago, capa do jogo | **Nano Banana**, pelos prompts em [avalon_prompts.md](avalon_prompts.md). Até lá, o app usa um marcador simples (carta na cor do lado com o símbolo e o nome) |
| Fichas de voto (Aprovar/Rejeitar), cartas de missão (Sucesso/Falha), trilha de missões, ficha de recusa, coroa do líder, verso da carta de papel, ícone do jogo no hub | Eu, em SVG, no mesmo traço do hub |

Como trocar: gere cada imagem, salve em `games/avalon/art/` (nomes na lista de prompts) e rode `tools/sync_web_assets.sh`. O app e a página usam a imagem se ela existir, senão o marcador. As imagens vão **uma vez só** no APK, como arquivo cru (importer "keep"): o app lê o arquivo e o `WebGateway` serve o mesmo em `/assets/avalon/`.

## 7. Arquitetura

```
games/avalon/
├── rules/avalon_rules.gd     # estado + apply(ação) → eventos; puro, com semente, testável
├── session/                  # avalon_session, avalon_host, avalon_client
├── screens/                  # menu, criar sala, jogo (jogador), tabuleiro, como jogar
├── ui/                       # carta de papel, trilha de missões, fichas
└── art/                      # SVG meus + PNG do Nano Banana
web/avalon.js                 # jogador e tabuleiro no navegador
```

## 8. Marcos

| Marco | Entrega | Critério de pronto |
|---|---|---|
| A1 Regras | `AvalonRules` + testes | Tabela certa pra 5 a 10; quem vê quem; voto; 5 recusas; 2 falhas na 4ª; Dama; assassinato; validação dos personagens |
| A2 Rede e app | Sessões, sala, telas do jogador e do tabuleiro | Partida inteira com robôs de rede |
| A3 Navegador | `web/avalon.js`, jogador e tabuleiro | Partida com o navegador no meio dos robôs |
| A4 Arte | SVGs, marcadores, prompts | Capturas de todas as telas |
| A5 Playtest | Partida real | Lista de ajustes resolvida |

## 9. Riscos

| Risco | Mitigação |
|---|---|
| Alguém olhar o celular do vizinho na hora do papel | "Esconder" e "Meu papel" pra espiar só quando quiser |
| Queda de alguém que está no time da missão | O jogo espera; a pessoa volta pelo mesmo aparelho |
| Arte gerada com estilos diferentes entre si | Prompts com o mesmo bloco de estilo, fundo e enquadramento |

## 10. Pendências

| # | Pergunta |
|---|---|
| **P1** | Revisar as **[proposta]**: validação dos personagens, botão "Pronto" depois de ver o papel, botão "Meu papel", quem aperta "Continuar", o jogo esperar quem caiu, direção de arte. |

## 11. Status da implementação (2026-09-26)

| Marco | Status |
|---|---|
| A1 Regras | ✓ `AvalonRules` + 16 testes (`tests/test_avalon_rules.gd`) |
| A2 Rede e app | ✓ `tools/avalon_net_test.sh`: 5 jogadores + 1 tabuleiro jogam uma partida inteira; um jogador cai e volta; os robôs conferem que ninguém recebe papel que não devia |
| A3 Navegador | ✓ `web/avalon.js` (jogador e tabuleiro). Testado no navegador, como jogador e como tabuleiro, até o fim da partida |
| A4 Arte | ✓ SVGs meus (fichas, cartas de missão, coroa, Dama, emblemas, ícone) e as 15 imagens do Nano Banana ([avalon_prompts.md](avalon_prompts.md)): 12 retratos nas cartas, Dama do Lago na fase da Dama, capa no menu e na sala do navegador, mesa clarinha no fundo do tabuleiro |
| A5 Playtest | **Falta** |

Detalhes que entraram na implementação:
- **Tabuleiro pelo navegador**: a página do jogo tem "Sou o tabuleiro (TV ou notebook)". Ele usa um id de aparelho próprio, então o mesmo navegador pode abrir um jogador e um tabuleiro.
- **"Entrar numa sala"** no app agora tem "Entrar como tabuleiro (não joga)" pra Chapéu e Avalon.
- A trilha de missões mostra o tamanho de cada missão, "2 falhas" na 4ª (7+), o resultado e as recusas.

