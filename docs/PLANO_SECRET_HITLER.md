# gamehub — Plano do Secret Hitler

> Status: v2 · 2026-09-26 · implementado (ver §11); falta a arte do Nano Banana e testar com pessoas
> Escopo: quarto jogo do hub, **Secret Hitler**, pelo **Wi-Fi** (app ou navegador), com **tabuleiro opcional**. Mesmo desenho do Avalon.

Legenda (a mesma dos outros planos): **[decidido]** veio das suas respostas; **[proposta]** é sugestão minha (lista em §10); **[verificar]** precisa ser confirmado.

---

## 1. Visão geral

Jogo de papéis secretos, de 5 a 10 pessoas. Os **liberais** são maioria mas não sabem quem é quem; os **fascistas** se conhecem e tentam eleger o **Hitler** chanceler ou aprovar 6 leis fascistas. A cada rodada um presidente indica um chanceler, todos votam o governo e, se aprovado, os dois aprovam uma lei tirada do baralho em segredo. As leis fascistas dão poderes ao presidente (investigar, espiar o baralho, eleição especial, executar).

O app substitui o "todo mundo fecha o olho" (cada celular mostra o papel e o que a pessoa sabe), a votação (Ja/Nein, revelada junto), o baralho de leis (o presidente e o chanceler escolhem no celular, ninguém mais vê) e os poderes secretos (a investigação e a espiada aparecem só no celular do presidente). A conversa e as mentiras continuam na mesa.

## 2. Decisões [decidido]

| Área | Decisão |
|---|---|
| Nome e tema | **Nome e termos originais** (Secret Hitler, Liberais, Fascistas, Hitler, Presidente, Chanceler), em português. **Arte neutra**: figuras políticas genéricas dos anos 30, **sem nenhum símbolo real** (nada de suástica, uniforme ou rosto de pessoa real) |
| Modos | Igual ao Avalon: cada um no seu celular, pelo **app** (Android) ou pelo **navegador** (iPhone) |
| Tabuleiro | **Opcional**, como no Avalon: quem cria a sala escolhe se joga ou se é o tabuleiro; outro aparelho pode entrar como tabuleiro pelo app ou pelo navegador |
| Jogadores | **5 a 10** |
| Regras | **Oficiais completas**: poderes pela contagem de jogadores, veto depois de 5 leis fascistas, caos com 3 eleições fracassadas, limite de mandato, Hitler chanceler depois de 3 leis fascistas vence |
| Voto do governo | Ja/Nein no celular, secreto até o último votar; aí aparece **o voto de cada um, com nome** (o voto é aberto no jogo oficial) |
| Sessão legislativa | **Só na conversa**: o app mostra só a lei aprovada; o que cada um diz que recebeu fica na mesa |
| Executado | **Espectador às cegas**: não vota, não pode ser indicado, continua vendo só o que é público |
| Cronômetro | **Opcional, o host liga** (1 a 5 min), pra discussão antes do presidente indicar; é só um aviso (igual ao Avalon) |
| Ordem da mesa | O **host arruma** na sala; o primeiro presidente é sorteado; a presidência passa em sentido horário |

## 3. Regras

### 3.1 Papéis por número de jogadores

| Jogadores | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|
| Liberais | 3 | 4 | 4 | 5 | 5 | 6 |
| Fascistas (sem contar o Hitler) | 1 | 1 | 2 | 2 | 3 | 3 |
| Hitler | 1 | 1 | 1 | 1 | 1 | 1 |

O host não escolhe papéis: a tabela decide.

### 3.2 O que cada um sabe no começo

| Papel | Vê no começo |
|---|---|
| Liberal | Nada |
| Fascista | Os outros fascistas **e quem é o Hitler** |
| Hitler, com 5 ou 6 jogadores | Quem é o fascista |
| Hitler, com 7 a 10 jogadores | **Nada** |

### 3.3 Baralho de leis

- 17 leis: **6 liberais e 11 fascistas**, embaralhadas.
- Se sobrarem **menos de 3** no baralho no fim de uma rodada, o descarte volta pro baralho e tudo é embaralhado.
- Todo mundo vê quantas leis tem no baralho e no descarte; ninguém vê quais.

### 3.4 Uma rodada

1. **Candidato a presidente**: o próximo vivo na ordem da mesa (ou o escolhido numa eleição especial, §3.6).
2. **Indicar o chanceler**: o presidente escolhe um jogador vivo, que não seja ele. **Não pode** indicar quem foi o último **presidente eleito** nem o último **chanceler eleito**. Com só 5 jogadores vivos, só o último chanceler fica impedido. Eleição que fracassou não muda esses impedimentos. Se o cronômetro estiver ligado, ele corre aqui.
3. **Votar o governo**: todos os vivos votam Ja ou Nein. Aparece quem já votou (não o voto). Quando o último vota, os votos aparecem todos juntos.
   - **Maioria de Ja** (mais da metade dos vivos): o governo é eleito.
     - Se já tem **3 ou mais leis fascistas** e o chanceler eleito é o **Hitler**, os fascistas vencem na hora.
     - Se já tem 3 ou mais leis fascistas e o chanceler **não** é o Hitler, o app anuncia "Caio não é o Hitler" (no jogo físico todo mundo fica sabendo, porque ele teria que se revelar).
   - **Empate ou maioria de Nein**: o governo cai, o **marcador de eleições** sobe e a presidência passa pro próximo.
   - **3 eleições fracassadas seguidas: caos.** A lei do topo do baralho é aprovada direto, **sem poder** (mesmo que caia numa casa com poder), o marcador zera e os impedimentos de mandato somem (qualquer um pode ser o próximo chanceler).
4. **Sessão legislativa** (governo eleito):
   - O presidente recebe as **3 leis do topo**, descarta 1 em segredo e passa as outras 2 pro chanceler.
   - O chanceler descarta 1 e **aprova a outra**.
   - A lei aprovada aparece pra todos; as descartadas vão pro descarte sem ninguém ver.
   - O marcador de eleições zera sempre que uma lei é aprovada (pelo governo ou pelo caos).
5. **Veto** (só depois de **5 leis fascistas**): com as 2 leis na mão, o chanceler pode pedir veto em vez de aprovar. Se o presidente aceitar, as 2 vão pro descarte, nenhuma lei entra e o **marcador de eleições sobe** (podendo dar caos). Se o presidente recusar, o chanceler é obrigado a aprovar uma das 2.
6. **Poder do presidente**: se a lei aprovada pelo governo for fascista e a casa dela tiver poder (§3.5), o presidente **é obrigado** a usar antes da próxima rodada.

### 3.5 Poderes na trilha fascista

| Casa da lei fascista | 1ª | 2ª | 3ª | 4ª | 5ª | 6ª |
|---|---|---|---|---|---|---|
| **5–6 jogadores** | — | — | Espiar o baralho | Execução | Execução + veto | Fascistas vencem |
| **7–8 jogadores** | — | Investigar | Eleição especial | Execução | Execução + veto | Fascistas vencem |
| **9–10 jogadores** | Investigar | Investigar | Eleição especial | Execução | Execução + veto | Fascistas vencem |

A partir da **3ª** lei fascista, eleger o Hitler chanceler dá vitória aos fascistas (§3.4).

### 3.6 Os poderes

- **Investigar**: o presidente escolhe alguém que ainda não foi investigado e vê, **só no celular dele**, o partido da pessoa: Liberal ou Fascista (o Hitler aparece como **Fascista**). Todo mundo vê "Ana investigou Caio", mas não o resultado.
- **Espiar o baralho**: o presidente vê, só no celular dele, as 3 leis do topo, na ordem. Nada muda no baralho.
- **Eleição especial**: o presidente escolhe **qualquer outro jogador vivo** (mesmo impedido de mandato) pra ser o próximo candidato a presidente. Depois dessa rodada, a presidência volta pra ordem normal, a partir de quem vinha depois do presidente que chamou a eleição.
- **Execução**: o presidente escolhe alguém pra executar (com confirmação). Se for o **Hitler**, os liberais vencem na hora. Se não, o papel **não é revelado** e a pessoa vira espectadora às cegas.

### 3.7 Fim

- **Liberais vencem**: 5 leis liberais aprovadas, ou o Hitler executado.
- **Fascistas vencem**: 6 leis fascistas aprovadas, ou o Hitler eleito chanceler com 3 ou mais leis fascistas na mesa.
- No fim, todos os papéis aparecem pra todo mundo, e também o histórico das rodadas (governos, votos, leis aprovadas) [proposta: incluir também **o que cada presidente e chanceler realmente recebeu e descartou**. Durante o jogo isso nunca aparece, mas no fim é o grande momento de "eu sabia que você mentiu"].

## 4. Telas

### 4.1 Celular do jogador (app e navegador)

- **Sala**: ordem da mesa (o host arruma), cronômetro, QR (app/navegador) e "Copiar endereço" (host). Não tem escolha de papéis.
- **Seu papel**: carta com a arte, o **partido** e o que a pessoa sabe ("Os fascistas são: Ana, Caio. O Hitler é: Bia"). Botões "Esconder" e "Pronto", e o botão fixo **"Meu papel"** no jogo, iguais ao Avalon.
- **Indicar chanceler**: o presidente vê a lista dos vivos; os impedidos aparecem apagados, com o motivo ("último chanceler"). Depois do toque, confirmação. Os outros veem "Ana está escolhendo o chanceler" e a escolha ao vivo.
- **Votar**: duas cartas grandes, **Ja!** e **Nein** [proposta: manter "Ja!"/"Nein" do original, com "sim"/"não" pequeno embaixo]. Depois do voto: "Você votou: Ja!" e quem falta votar.
- **Resultado do voto**: lista com o voto de cada um, eleito ou não.
- **Sessão legislativa**:
  - Presidente: as 3 leis viradas pra cima; toca na que quer **descartar**, confirma.
  - Chanceler: as 2 leis; toca na que quer **aprovar**, confirma. Depois de 5 fascistas, aparece também "Pedir veto".
  - Pedido de veto: o presidente vê "O chanceler pediu veto" com Aceitar e Recusar.
  - Os outros veem "O governo está decidindo a lei", sem nenhuma pista.
- **Lei aprovada**: a carta vira na tela de todo mundo.
- **Poder**: o presidente vê a ação (escolher alguém, ou ver as 3 leis); os outros veem "Ana está investigando". O resultado da investigação e o da espiada ficam num cartão que só o presidente vê, com "Esconder".
- **Executado**: "Você foi executado. Não pode falar do seu papel" e a visão pública do jogo.
- **Fim**: quem venceu e por quê, todos os papéis e o histórico (§3.7).
- Placar sempre visível no topo: as duas trilhas (liberal 5 casas, fascista 6 casas com os ícones dos poderes), o marcador de eleições, o baralho e o descarte, quem é o presidente e quem é o chanceler.

### 4.2 Tabuleiro (app ou navegador, tela grande)

- Na sala: QR grande, lista de quem entrou.
- No jogo: as duas trilhas grandes com os poderes, o marcador de eleições, baralho e descarte, a mesa com os nomes (presidente, chanceler indicado, impedidos, executados), quem já votou, os votos revelados, a lei aprovada virando, "Caio não é o Hitler". **Nunca mostra nada secreto.**
- "Continuar" depois de cada resultado: o tabuleiro, o host e o presidente da vez podem apertar, igual ao Avalon.

### 4.3 Cuidados pra não vazar informação [proposta]

- **Todos os celulares vibram e tocam igual** nas fases secretas. Por exemplo, na sessão legislativa não vibra só o celular do presidente e do chanceler; vibra o de todo mundo quando a sessão começa e quando a lei sai.
- As telas de quem espera têm o mesmo tamanho e o mesmo movimento, pra quem olha de longe não perceber nada.
- As cartas secretas (leis na mão, resultado da investigação, espiada) somem sozinhas depois que a ação termina.

## 5. Rede

- Igual ao Avalon: host autoritativo, `Net` (ENet) pro app e `WebGateway` pro navegador, estado filtrado por quem está vendo. Cada um só recebe o próprio papel e o que ele sabe; as leis na mão só chegam ao presidente ou ao chanceler da vez; o tabuleiro não recebe nada secreto até o fim.
- Descoberta, QR, código e reconexão pelo id do aparelho iguais; a sala some da descoberta quando a partida começa.
- Queda no meio: **o jogo espera** [proposta, igual ao Avalon]. Não tem remover jogador no meio.

## 6. Arte

Direção [proposta, minha escolha]: a mesma do Avalon, **ilustração em guache e nanquim sobre papel creme**, com cara de **cartaz político dos anos 30** (ternos, chapéus, gravatas, jornais, microfones antigos): **liberais no cobalto**, **fascistas no tomate**. **Sem nenhum símbolo real**: nada de suástica, braçadeira, águia, uniforme militar ou rosto de pessoa real. O Hitler vira uma **figura misteriosa de chapéu e sobretudo, com o rosto na sombra** e olhos que brilham. É o jeito mais seguro de o Nano Banana aceitar e não ficar de mau gosto.

| Peça | Quem faz |
|---|---|
| Retratos: Liberal ×4 variações, Fascista ×3 variações, Hitler; capa (16:9); fundo do tabuleiro (16:9) | **Nano Banana**, pelos prompts que eu vou escrever em `docs/secret_hitler_prompts.md` (mesmo bloco de estilo do Avalon, trocando o tema). Até lá, o app usa um marcador simples (carta na cor do partido com o nome) |
| Cartas de lei (liberal/fascista), cartas de voto Ja!/Nein, cartão de partido (Liberal/Fascista), plaquinhas de Presidente e Chanceler, trilhas, marcador de eleições, ícones dos poderes (lupa, olho, urna, alvo), veto, verso da carta, ícone do jogo no hub | Eu, em SVG, no mesmo traço do hub |

Como trocar: igual ao Avalon (`games/secret_hitler/art/`, `tools/sync_web_assets.sh`, fallback pra variação que existir e depois pro marcador).

## 7. Arquitetura

```
games/secret_hitler/
├── rules/sh_rules.gd        # estado + apply(ação) → eventos; puro, com semente, testável
├── session/                 # sh_session, sh_host, sh_client (copiados do Avalon e adaptados)
├── screens/                 # menu, criar sala, como jogar, jogo (jogador e tabuleiro na mesma tela, como no Avalon)
├── ui/                      # sh_art: carta de papel, trilhas, cartas de lei
└── art/                     # SVG meus + imagens do Nano Banana
web/sh.js                    # jogador e tabuleiro no navegador
tests/test_sh_rules.gd
tools/sh_bot.gd, tools/sh_net_test.sh
```

Reaproveitamento [proposta]: copio a estrutura das sessões e da tela do Avalon e adapto. Só extraio código compartilhado se ficar claramente igual nos dois (tipo a sala com a ordem da mesa, a carta de papel com "Esconder" e o "Meu papel"). Nada de refatorar o Avalon antes.

Entradas no hub: card na home (no lugar de um "em breve"), "Entrar numa sala" reconhece o jogo `secret_hitler`, histórico com quem venceu, como e os papéis.

## 8. Marcos

| Marco | Entrega | Critério de pronto |
|---|---|---|
| S1 Regras | `ShRules` + testes | Tabela de papéis de 5 a 10; quem vê quem (Hitler com 5–6 e com 7+); baralho e reembaralhamento; impedimentos de mandato (inclusive com 5 vivos e depois do caos); voto; caos sem poder; trilhas de poder pras 3 faixas; investigar (Hitler aparece fascista, não repete), espiar, eleição especial (e a volta da ordem), execução (Hitler e não Hitler); veto aceito e recusado; as 4 vitórias; "não é o Hitler"; filtro do que cada um vê |
| S2 Rede e app | Sessões, sala, telas do jogador e do tabuleiro | Partida inteira com robôs de rede, que conferem que ninguém recebe o que não devia |
| S3 Navegador | `web/sh.js`, jogador e tabuleiro | Partida com o navegador no meio dos robôs |
| S4 Arte | SVGs, marcadores, prompts | Capturas de todas as telas |
| S5 Playtest | Partida real | Lista de ajustes resolvida |

## 9. Riscos

| Risco | Mitigação |
|---|---|
| Vazar informação por vibração, som ou tempo de tela | §4.3: todo mundo vibra junto, telas de espera iguais |
| Alguém olhar o celular do presidente na hora das leis | Cartas grandes só durante a escolha, "Esconder", somem depois |
| Nano Banana recusar a arte por causa do tema | Prompts sem nomes nem símbolos reais, só "1930s politician", "shadowy figure" |
| Queda do presidente ou do chanceler no meio da sessão legislativa | O jogo espera; as leis na mão ficam guardadas no host e voltam pra ele quando reconectar |
| Tema pesado | Nome original só porque o app é interno (§10, P2) |

## 10. Pendências

| # | Pergunta |
|---|---|
| **P1** | Revisar as **[proposta]**: mostrar no fim o que cada governo recebeu e descartou (§3.7), "Ja!/Nein" do original (§4.1), cuidados de vibração e tela (§4.3), o jogo esperar quem caiu (§5), direção de arte (§6), copiar do Avalon sem refatorar (§7). |
| **P2** | [verificar] **Licença**: o Secret Hitler é CC BY-NC-SA 4.0 (Goat, Wolf & Cabbage). Pode adaptar sem fins comerciais, dando crédito e mantendo a mesma licença. Vou pôr os créditos no "Como jogar". Com esse nome, **este jogo não pode ir pra Play Store**: se um dia o app for publicado, ele sai do build ou troca de nome e tema. |

## 11. Status da implementação (2026-09-26)

As **[proposta]** entraram como estão no plano (histórico secreto no fim, "Ja!/Nein", vibração igual pra todos, o jogo esperar quem caiu, direção de arte, cópia do Avalon sem refatorar); dá pra mudar qualquer uma depois do playtest.

| Marco | Status |
|---|---|
| S1 Regras | ✓ `ShRules` + 13 testes (`tests/test_sh_rules.gd`): tabela de papéis, quem sabe quem, impedimentos (com 5 vivos e depois do caos), caos sem poder, reembaralhamento, poderes das 3 faixas, eleição especial e a volta da ordem, execução (Hitler e não Hitler), veto aceito e recusado, as 4 vitórias, filtro do que cada um vê |
| S2 Rede e app | ✓ `tools/sh_net_test.sh`: 7 jogadores + 1 tabuleiro jogam uma partida inteira; um cai e volta; os robôs conferem que ninguém recebe papel, leis ou espiada que não devia. Também rodado com 5, 6, 9 e 10 jogadores |
| S3 Navegador | ✓ `web/sh.js` (jogador e tabuleiro). Testado no navegador: papel, voto, lei na mão do chanceler, recarregar a página no meio e voltar pra mesma vaga, tabuleiro |
| S4 Arte | Parcial: SVGs meus (cartas de lei com ramo de oliveira e caveira, cédulas Ja!/Nein, cartão de partido, verso, ícones dos poderes, veto, chapéu do ícone do jogo) e marcadores. **Falta**: gerar os 8 retratos, a capa e a mesa no Nano Banana ([secret_hitler_prompts.md](secret_hitler_prompts.md)) |
| S5 Playtest | **Falta** |

Detalhes que entraram na implementação:
- "Trocar aparelho" (`net/seat_transfer.gd`) já vale pro Secret Hitler: host ou tabuleiro abre o QR da vaga de quem caiu.
- O executado vê "Você foi executado" no topo de todas as telas e continua vendo só o que é público.
- O fundo da tela "Meu papel" é opaco, pra ninguém ver o papel por trás.
