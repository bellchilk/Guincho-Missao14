from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
custom_manifest = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"

# O flutter create pode recriar arquivos de plataforma. Este script garante
# as permissões necessárias após essa etapa.
manifest = """<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.CAMERA" />

    <uses-feature android:name="android.hardware.camera" android:required="true" />
    <uses-feature android:name="android.hardware.bluetooth_le" android:required="false" />

    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

    <uses-permission android:name="android.permission.BLUETOOTH"
        android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN"
        android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
        android:maxSdkVersion="30" />

    <application
        android:label="Guincho Inteligente"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:hardwareAccelerated="true">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data android:name="flutterEmbedding" android:value="2" />
    </application>

    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
    </queries>
</manifest>
"""

custom_manifest.parent.mkdir(parents=True, exist_ok=True)
custom_manifest.write_text(manifest, encoding="utf-8")

proguard = ROOT / "android" / "app" / "proguard-rules.pro"
proguard.write_text("-keep class com.lib.flutter_blue_plus.** { *; }\n", encoding="utf-8")

print("Permissões Android aplicadas.")
