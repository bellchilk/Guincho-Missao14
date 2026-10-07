@echo off
echo ===========================================
echo  CLUBROBOT - MISSAO 14 - GERAR APK
echo ===========================================
echo.

flutter create --platforms=android .
if errorlevel 1 goto erro

python tool\patch_android.py
if errorlevel 1 goto erro

flutter pub get
if errorlevel 1 goto erro

flutter build apk --release
if errorlevel 1 goto erro

echo.
echo APK criado em:
echo build\app\outputs\flutter-apk\app-release.apk
echo.
pause
exit /b 0

:erro
echo.
echo O build encontrou um erro.
echo Copie a mensagem do terminal para diagnosticar.
pause
exit /b 1
