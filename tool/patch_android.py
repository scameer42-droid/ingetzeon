#!/usr/bin/env python3
"""Menyiapkan folder android/ untuk IngetZeon (aman dijalankan berulang kali).

Dipanggil otomatis oleh GitHub Actions setelah `flutter create`.
Kalau build di komputer sendiri: jalankan `python3 tool/patch_android.py` sekali
setelah `flutter create --platforms=android --org com.zeon .`
"""
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ANDROID = ROOT / "android"
APP = ANDROID / "app"
MANIFEST = APP / "src" / "main" / "AndroidManifest.xml"

PERMISSIONS = [
    '<uses-permission android:name="android.permission.INTERNET"/>',
    '<uses-permission android:name="android.permission.RECORD_AUDIO"/>',
    '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
    '<uses-permission android:name="android.permission.VIBRATE"/>',
    '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>',
    '<uses-permission android:name="android.permission.WAKE_LOCK"/>',
    '<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>',
    '<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32"/>',
    '<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>',
]

RECEIVERS = """
        <!-- flutter_local_notifications: alarm terjadwal & setelah HP restart -->
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""

QUERIES = """
        <!-- speech_to_text & flutter_tts (Android 11+) -->
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
"""


def patch_manifest():
    s = MANIFEST.read_text()
    if "ScheduledNotificationReceiver" in s:
        print("Manifest sudah dipatch")
        return
    perms = "\n".join("    " + p for p in PERMISSIONS)
    s = s.replace("<application", perms + "\n\n    <application", 1)
    s = re.sub(r'android:label="[^"]*"', 'android:label="IngetZeon"', s, count=1)
    s = s.replace("</application>", RECEIVERS + "    </application>", 1)
    # layar alarm tampil di atas layar kunci & menyalakan layar
    s = s.replace('android:name=".MainActivity"', 'android:name=".MainActivity"\n            android:showWhenLocked="true"\n            android:turnScreenOn="true"', 1)
    if "<queries>" in s:
        s = s.replace("<queries>", "<queries>" + QUERIES, 1)
    else:
        s = s.replace("</manifest>", "    <queries>" + QUERIES + "    </queries>\n</manifest>", 1)
    MANIFEST.write_text(s)
    print("Manifest dipatch")


def patch_gradle():
    kts = APP / "build.gradle.kts"
    groovy = APP / "build.gradle"
    if kts.exists():
        f = kts
        s = f.read_text()
        if "isCoreLibraryDesugaringEnabled" not in s:
            s = s.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
            s = s.rstrip() + '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        if "proguard-rules.pro" not in s:
            s = re.sub(r"(release\s*\{)", r'\1\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")', s, count=1)
        if "checkReleaseBuilds" not in s:
            s = s.replace("android {", "android {\n    lint {\n        checkReleaseBuilds = false\n        abortOnError = false\n    }", 1)
        # minSdk minimal 23 (speech_to_text & notifikasi)
        s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = maxOf(flutter.minSdkVersion, 23)", s)
    elif groovy.exists():
        f = groovy
        s = f.read_text()
        if "coreLibraryDesugaringEnabled" not in s:
            s = s.replace("compileOptions {", "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
            s = s.rstrip() + "\n\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
        if "proguard-rules.pro" not in s:
            s = re.sub(r"(release\s*\{)", r"\1\n            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'", s, count=1)
        if "checkReleaseBuilds" not in s:
            s = s.replace("android {", "android {\n    lintOptions {\n        checkReleaseBuilds false\n        abortOnError false\n    }", 1)
        s = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion Math.max(flutter.minSdkVersion, 23)", s)
        s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = Math.max(flutter.minSdkVersion, 23)", s)
    else:
        raise SystemExit("build.gradle tidak ditemukan")
    f.write_text(s)
    (APP / "proguard-rules.pro").write_text(
        "# flutter_local_notifications (Gson)\n"
        "-keep class com.dexterous.** { *; }\n"
        "-keep class com.google.gson.** { *; }\n"
        "-keepattributes Signature\n"
        "-keepattributes *Annotation*\n"
        "-dontwarn com.google.android.play.core.**\n"
    )
    print(f"{f.name} dipatch")


def copy_resources():
    src = ROOT / "tool" / "android_res"
    dst = APP / "src" / "main" / "res"
    for folder in src.iterdir():
        target = dst / folder.name
        target.mkdir(parents=True, exist_ok=True)
        for file in folder.iterdir():
            shutil.copy2(file, target / file.name)
    print("Ikon disalin")


if __name__ == "__main__":
    patch_manifest()
    patch_gradle()
    copy_resources()
