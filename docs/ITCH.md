# Publicar no itch.io

O GameHub vai pro itch.io como **APK de Android**, grátis com doação opcional, numa página pública. O site do itch é em inglês, então os nomes dos campos abaixo estão como aparecem lá.

## O que já está pronto

| O quê | Onde | Como gerar de novo |
|---|---|---|
| APK pra baixar | `build/itch/GameHub-<versão>.apk` | `tools/build_android.sh itch` |
| Capa (630×500) | `design/itch/cover_630x500.png` | `tools/itch_assets.py` |
| Capturas de tela | `design/itch/shots/` | tour + `tools/itch_assets.py /pasta/do/tour` (veja o cabeçalho do script) |
| Textos da página | esta página, seção "Textos" | — |

## Passo a passo

### 1. Conta

1. Crie a conta em https://itch.io/register (ou entre com a que já tiver).
2. Em **Settings → Payments**, só se quiser receber doações: preencha o PayPal ou os dados de pagamento. Dá pra fazer depois; sem isso, o botão de doação não aparece.

### 2. Criar a página

1. No menu da sua conta (canto de cima, à direita), clique em **Upload new project**.
2. Preencha:

| Campo | O que colocar |
|---|---|
| **Title** | `GameHub` |
| **Project URL** | `gamehub` (fica `https://SEU_USUARIO.itch.io/gamehub`) |
| **Short description or tagline** | o texto de "Frase curta", abaixo |
| **Classification** | `Games` |
| **Kind of project** | `Downloadable` |
| **Release status** | `Released` |
| **Pricing** | `$0 or donate` (grátis, com doação opcional). Em **Suggested donation**, `$2.00` ou deixe vazio |

### 3. Enviar o APK

1. Em **Uploads**, clique em **Upload files** e escolha `build/itch/GameHub-2.0.0.apk`.
2. Quando terminar de subir, marque a caixa **Android** embaixo do arquivo.
3. Deixe **This file will be played in the browser** desmarcada.

### 4. Descrição

1. Em **Details → Description**, cole o texto de "Descrição", abaixo. O editor do itch mantém os títulos e as listas quando você cola.
2. **Genre**: `Card Game`.
3. **Tags** (até 10): `party-game`, `local-multiplayer`, `multiplayer`, `board-game`, `card-game`, `social-deduction`, `bluffing`, `word-game`, `android`, `portuguese`.
4. **AI generation disclosure**: marque **Yes**, e em seguida **Graphics**. As ilustrações dos jogos foram geradas com IA (Nano Banana); o itch exige essa declaração, e omitir pode tirar a página do ar.

### 5. Metadados (seção "Metadata", às vezes em "More details")

| Campo | O que marcar |
|---|---|
| **Languages** | `Portuguese (Brazil)` |
| **Inputs** | `Touchscreen` |
| **Multiplayer** | `Local multiplayer` e `Ad-hoc networked multiplayer` (é rede local, sem servidor) |
| **Player count** | `2` a `20` |
| **Average session** | `About a half-hour` |
| **Accessibility** | deixe vazio |

### 6. Imagens

1. **Cover image**: `design/itch/cover_630x500.png`.
2. **Screenshots**: todas as imagens de `design/itch/shots/`, na ordem dos nomes.
3. **Gameplay video or trailer**: deixe vazio por enquanto.

### 7. Publicar

1. Em **Visibility & access**, deixe **Draft** e clique em **Save & view page**.
2. Confira a página (e baixe o APK por ela, num celular, pra ter certeza de que instala).
3. Volte em **Edit game**, mude pra **Public** e salve.

### 8. Cor da página (opcional)

Na página do jogo, clique em **Edit theme** e use:

- **Background**: `#F5EFE3` · **Text**: `#1F1D1A` · **Links**: `#2B59C3` · **Buttons**: `#E3AC2A`.
- Fonte: qualquer uma sem serifa.

## Atualizar a versão no itch

1. Suba o número da versão em `export_presets.cfg` (`version/code` e `version/name`, nos dois presets do Android).
2. Rode `tools/build_android.sh itch`.
3. Em **Edit game → Uploads**, envie o APK novo, marque **Android** e apague o antigo (ou deixe os dois, com o novo em cima).

## Cuidados

- **APK do itch e app da Play não se atualizam entre si.** O APK do itch é assinado com a chave de upload; o que a Play entrega é assinado pela chave do Google. Os dois têm o mesmo pacote (`com.softbuilders.gamehub`), então quem instalou por um precisa desinstalar antes de instalar pelo outro, e perde o histórico de partidas.
- **Doação e Secret Hitler**: a licença do Secret Hitler (CC BY-NC-SA 4.0) proíbe uso comercial. Doação opcional é uma área cinzenta; se aparecer algum problema, mude o **Pricing** pra `No payments`.
- **Marcas**: a página diz que é projeto de fã e dá os créditos (veja "Créditos", abaixo). Se alguma editora pedir pra tirar, o itch avisa por e-mail; aí trocamos o nome do jogo no app.

---

## Textos

### Frase curta

```
8 jogos de festa pra jogar junto, cada um no seu celular, pelo Wi-Fi de casa.
```

### Descrição

```
GameHub junta 8 jogos de festa num app só. Cada um joga no seu celular, conectado pelo mesmo Wi-Fi, sem internet, sem cadastro e sem anúncios. Quem não tem o app entra pelo navegador, lendo o QR code da sala (funciona no iPhone também). Um tablet ou notebook pode virar o tabuleiro no meio da mesa.

OS JOGOS

• Chapéu (4 a 12): todo mundo escreve palavras, tudo vai pro chapéu e dois times tentam adivinhar em três rodadas: descrevendo, com uma palavra só e na mímica.
• Halli Galli (2 a 20): cada celular deitado na mesa é a sua carta. Arraste pra virar; quando a mesa tiver exatamente 5 de uma fruta, toque duas vezes pra bater o sino. Quem bateu primeiro é decidido pelo instante do toque, não pela velocidade da rede.
• Avalon (5 a 10): leais contra traidores. Cada um vê o seu papel em segredo, o grupo escolhe quem vai nas missões e os votos são revelados juntos.
• Secret Hitler (5 a 10): liberais contra fascistas, com leis, votações e poderes presidenciais. Cada celular mostra só o que aquela pessoa pode saber.
• Coup (2 a 6): blefe puro. Diga que tem o Duque, pegue as moedas e torça pra ninguém duvidar.
• Quem Foi? (3 a 6): acharam um cocô no meio da sala e foi o bicho de alguém. Acuse, passe a culpa e seja rápido.
• Sintonia (2 a 12): uma pessoa dá uma dica e o grupo tenta acertar onde o alvo está entre dois extremos.
• Ito (2 a 10): cada um recebe um número secreto e dá uma dica sobre ele no tema da rodada. Juntos, vocês tentam pôr os números em ordem sem dizer nenhum.

COMO JOGAR JUNTO

1. Todo mundo no mesmo Wi-Fi (o roteador de casa ou o roteador do celular de alguém).
2. Uma pessoa cria a sala.
3. Os outros entram pelo código, pelo QR code ou encontram a sala automaticamente.

Android 12 ou mais novo. O app é em português.

CRÉDITOS

GameHub é um projeto de fã, gratuito, sem ligação com as editoras dos jogos originais.
• Halli Galli é um jogo de Haim Shafir, publicado pela AMIGO.
• The Resistance: Avalon e Coup são publicados pela Indie Boards & Cards.
• Secret Hitler é de Goat, Wolf & Cabbage, sob a licença CC BY-NC-SA 4.0 (creativecommons.org/licenses/by-nc-sa/4.0). Esta adaptação é não comercial e segue a mesma licença.
• Sintonia é inspirado em Wavelength; Ito, no jogo da Arclight; Quem Foi?, em Who Did It?, da Blue Orange Games.
• Fontes Fraunces e Manrope (SIL Open Font License). Ícones Phosphor (MIT).
• Ilustrações feitas com ajuda de IA.
```

### Instruções de instalação (campo "Install instructions", se aparecer)

```
1. Baixe o arquivo .apk no celular Android.
2. Abra o arquivo. Se o Android pedir, permita "Instalar apps desconhecidos" para o navegador ou o gerenciador de arquivos.
3. Toque em Instalar.
Se você já tem o GameHub da Play Store, desinstale antes: as duas versões não se atualizam entre si.
```
