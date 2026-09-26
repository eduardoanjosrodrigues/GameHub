# Android: build, teste no celular e publicação

## O que está instalado nesta máquina

| Item | Onde |
|---|---|
| Godot 4.7.2 + templates de export | `~/Downloads/`, `~/.local/share/godot/export_templates/4.7.2.stable` |
| Android SDK (platform-tools, build-tools 36.1.0, platform 36, NDK 29) | `~/Android/Sdk` |
| JDK 17 (Temurin) | `~/.local/jdk-17` (configurado no Godot em Editor Settings > Export > Android) |
| Chave de debug | `~/.local/share/godot/keystores/debug.keystore` |
| **Chave de upload da Play Store** | `~/.android-keys/gamehub-upload.jks` + senha em `~/.android-keys/gamehub-upload.txt` |

> **Faça backup da pasta `~/.android-keys` num lugar seguro** (gerenciador de senhas, pendrive). Com o Play App Signing ativado, dá pra pedir troca da chave de upload se ela se perder, mas o processo demora.

## Configuração do app

- Pacote: `com.eduardorodrigues.gamehub` (permanente depois da primeira publicação).
- Android 12+ (`minSdk 31`), `targetSdk 36`, só `arm64-v8a`, retrato.
- Permissões: internet, estado da rede e do Wi-Fi, multicast de Wi-Fi (descoberta de salas), vibração. **Não usa câmera.**
- Link `gamehub://entrar?c=CODIGO`: declarado em `android/build/src/main/AndroidManifest.xml` num alias próprio (`.GameHubJoinLink`), porque o Godot regenera o alias do launcher a cada export.

## Testar no seu celular

1. No celular: Configurações > Sobre o telefone > toque 7 vezes em "Número da versão". Depois, em Opções do desenvolvedor, ligue a **Depuração USB**.
2. Conecte no PC pelo cabo e aceite a pergunta "Permitir depuração USB?" no celular.
3. Rode:

```bash
tools/build_android.sh install
```

O que conferir no aparelho (não deu pra testar sem celular conectado):

- [ ] Layout e área segura (notch e barra de gestos).
- [ ] Teclado não cobrindo os campos na tela de escrever palavras.
- [ ] Vibração e sons.
- [ ] Criar sala no celular e entrar pelo PC (`godot --path .` > Entrar numa sala), pelos três caminhos: lista de salas, código e IP.
- [ ] Abrir a câmera do celular apontando pro QR de uma sala criada no PC. Nem todo app de câmera oferece abrir links `gamehub://`; se o seu não oferecer, o código da sala continua funcionando.

## Gerar o pacote da Play Store

```bash
tools/build_android.sh release
```

Sai `build/gamehub.aab`, assinado com a chave de upload. A cada nova versão, aumente `version/code` (e `version/name`) nos dois presets de `export_presets.cfg`.

## Publicar

1. Criar a conta de desenvolvedor no Google Play Console (taxa única de US$ 25).
2. Hospedar `docs/politica-de-privacidade.md` numa URL pública, preenchendo antes nome, e-mail e data.
3. Criar o app no Console e preencher a ficha com os textos de [PLAY_STORE.md](PLAY_STORE.md) e as imagens de `design/store/`.
4. Ativar o Play App Signing e subir o `build/gamehub.aab`.
5. Contas pessoais novas precisam de **teste fechado com pelo menos 12 testadores por 14 dias seguidos** antes de liberar a produção. Confirme a regra atual no Console.
6. Depois dos 14 dias, pedir acesso à produção.
