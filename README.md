# ClubRobot — Missão 14 Junior
## Guincho Inteligente: Minha própria IA

Este projeto Flutter foi feito para a dinâmica:

1. A criança abre o **Google Teachable Machine**.
2. Cria e treina um modelo de imagens.
3. Cria exatamente estas classes:
   - `PUNHO`
   - `MAO_ABERTA`
   - `JOINHA`
   - `ESQUERDA`
   - `DIREITA`
   - `NENHUM`
4. No Teachable Machine, usa:
   **Export Model > TensorFlow.js > Upload (shareable link)**.
5. Copia o endereço no formato:
   `https://teachablemachine.withgoogle.com/models/ABC123/`
6. Cola esse link no app.
7. O app carrega `model.json` e `metadata.json` do modelo da própria criança.
8. Primeiro ela usa **TESTAR IA**.
9. Depois conecta o ESP32 e usa **CONTROLAR**.

## Regras de segurança do app

- confiança abaixo de 85% -> `PARAR`
- `NENHUM` -> `PARAR`
- `MAO_ABERTA` -> `PARAR` imediatamente
- movimentos precisam ser reconhecidos 2 vezes consecutivas
- o modo inicial é **TESTAR IA**, sem enviar movimentos ao ESP32
- há um botão grande de **PARADA DE EMERGÊNCIA**

## Gestos e comandos BLE

| Classe | Comando | Ação |
|---|---|---|
| PUNHO | S | Subir |
| MAO_ABERTA | P | Parar |
| JOINHA | D | Descer |
| ESQUERDA | E | Esquerda |
| DIREITA | R | Direita |
| NENHUM | P | Parar |

## Importante sobre o modelo da criança

Os nomes das classes precisam ser exatamente os indicados acima.
O app verifica as classes quando o modelo é carregado e avisa se alguma estiver faltando.

O app NÃO possui um modelo fixo dentro do APK. Cada criança pode colar o próprio link compartilhável.

## Como usar na pasta Flutter que você já criou

Na pasta do seu projeto Flutter atual:

1. Substitua/copiem:
   - `lib/`
   - `assets/`
   - `pubspec.yaml`
   - `android/app/src/main/AndroidManifest.xml`
   - `android/app/proguard-rules.pro`
2. Rode:

```bash
flutter pub get
```

3. Para testar no celular físico:

```bash
flutter devices
flutter run -d ID_DO_CELULAR
```

## Como gerar APK localmente

Você pode dar dois cliques em:

```text
GERAR_APK.bat
```

ou usar:

```bash
flutter create --platforms=android .
python tool/patch_android.py
flutter pub get
flutter build apk --release
```

Ao terminar:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Como gerar APK SEM pesar o notebook — recomendado

O projeto já inclui:

```text
.github/workflows/build-apk.yml
```

Esse arquivo permite que o GitHub compile o APK em um computador na nuvem.

### Passos

1. Crie um repositório no GitHub.
2. Envie todo o conteúdo desta pasta.
3. Abra o repositório no GitHub.
4. Clique em **Actions**.
5. Abra **Gerar APK Android**.
6. Clique em **Run workflow**.
7. Espere o build terminar.
8. Abra a execução concluída.
9. Em **Artifacts**, baixe:
   `guincho-missao14-apk`
10. Dentro do ZIP estará:
   `app-release.apk`

Assim o notebook não precisa executar Gradle/NDK para criar o APK.

## ESP32

Na pasta:

```text
esp32/guincho_missao14.ino
```

há um exemplo de firmware BLE.

Nome anunciado:

```text
ESP32_GUINCHO
```

O app e o ESP32 usam estes UUIDs:

```text
Service:
6f400001-b5a3-f393-e0a9-e50e24dcca9e

Characteristic:
6f400002-b5a3-f393-e0a9-e50e24dcca9e
```

Antes de ligar servos, teste os comandos pelo Monitor Serial.

## Observação sobre internet

O celular precisa estar conectado à internet para:
- abrir o Teachable Machine;
- baixar o modelo pelo link compartilhável;
- carregar as bibliotecas TensorFlow.js/Teachable Machine usadas pela câmera.

Depois que o modelo é carregado, a inferência acontece no próprio dispositivo, mas a página é recriada quando o app é reaberto, então o link precisa ser carregado novamente.
