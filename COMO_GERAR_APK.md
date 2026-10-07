# COMO TRANSFORMAR EM APK

## Opção A — no seu computador

Abra um terminal dentro da pasta do projeto:

```bat
flutter pub get
flutter build apk --release
```

O APK fica em:

```text
build\app\outputs\flutter-apk\app-release.apk
```

### Se a pasta Android ainda não estiver completa

Execute antes:

```bat
flutter create --platforms=android .
python tool\patch_android.py
flutter pub get
flutter build apk --release
```

## Opção B — GitHub Actions (recomendada para notebook com pouca RAM)

O projeto já possui uma automação que gera o APK na nuvem.

1. Crie um repositório no GitHub.
2. Faça upload de todos os arquivos desta pasta.
3. Vá em **Actions**.
4. Escolha **Gerar APK Android**.
5. Clique em **Run workflow**.
6. Quando ficar verde, abra a execução.
7. Em **Artifacts**, baixe `guincho-missao14-apk`.
8. Extraia o ZIP.
9. O arquivo `app-release.apk` pode ser enviado aos celulares Android.

No Android, talvez seja necessário permitir
**Instalar apps desconhecidos** para o aplicativo usado para abrir o APK
(Arquivos, Drive, WhatsApp etc.).
