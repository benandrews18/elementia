"""Build the Android app (release-signed APK) and install it on a phone.

  python godot/tools/phone.py           build, then install on every phone adb sees
  python godot/tools/phone.py build     build only (build/android/elementia.apk)

Needs the setup in C:/Users/benan/Android (JDK 17, Android SDK, the release
keystore and its password file; see PLAN.md "Phone builds"). The keystore
never goes in the repo: Godot reads it from the environment here.
A phone on Wi-Fi is paired once with `adb pair` / `adb connect` (PLAN.md).
"""
import os
import subprocess
import sys
from pathlib import Path

ANDROID = Path("C:/Users/benan/Android")
GODOT = "C:/Users/benan/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
ADB = str(ANDROID / "sdk/platform-tools/adb.exe")
ROOT = Path(__file__).resolve().parents[1]
APK = ROOT / "build/android/elementia.apk"


def build() -> None:
    env = dict(os.environ,
               GODOT_ANDROID_KEYSTORE_RELEASE_PATH=str(ANDROID / "elementia-release.keystore"),
               GODOT_ANDROID_KEYSTORE_RELEASE_USER="elementia",
               GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=(ANDROID / "elementia-keystore-password.txt").read_text().strip())
    APK.parent.mkdir(parents=True, exist_ok=True)
    APK.unlink(missing_ok=True)
    subprocess.run([GODOT, "--headless", "--path", str(ROOT), "--export-release", "Android", str(APK)], env=env, check=True)
    if not APK.exists():  # Godot can exit 0 after a failed export
        sys.exit("Export failed: no APK (read Godot's errors above)")
    print(f"Built {APK} ({APK.stat().st_size / 1e6:.1f} MB)")


def install() -> None:
    lines = subprocess.run([ADB, "devices"], capture_output=True, text=True, check=True).stdout.splitlines()[1:]
    phones = [l.split()[0] for l in lines if l.endswith("\tdevice")]
    if not phones:
        sys.exit("No phone connected (adb devices is empty): pair it first, see PLAN.md")
    for p in phones:
        subprocess.run([ADB, "-s", p, "install", "-r", str(APK)], check=True)  # -r keeps the save
        subprocess.run([ADB, "-s", p, "shell", "monkey", "-p", "io.github.benandrews18.elementia", "1"],
                       capture_output=True)  # open it
        print(f"Installed on {p}")


if __name__ == "__main__":
    build()
    if sys.argv[1:] != ["build"]:
        install()
