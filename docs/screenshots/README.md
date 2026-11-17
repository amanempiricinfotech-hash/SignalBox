# Screenshots

Captured from a debug build running on an Android emulator (1080x2400, API 36).

## What you are looking at

| File | Data shown |
| --- | --- |
| `applications.png` | **Real.** The emulator's actual installed applications, read from the package manager, with their real launcher icons. |
| `settings.png` | **Real.** Includes the Developer section, which only exists in debug builds. |
| `dashboard.png` | Developer fixtures loaded. |
| `inbox.png` | Developer fixtures loaded. |
| `statistics.png` | Developer fixtures loaded. |
| `rules.png` | Developer fixtures loaded. |

SignalBox ships **no sample data**. A fresh install has an empty inbox,
an empty dashboard and empty statistics until the user grants notification
access and their own notifications start arriving.

Screens that need a populated database are therefore shown with the developer
fixtures loaded (**Settings > Developer > Load issue fixtures**, debug builds
only). Those entries are deliberately fictional — "Fixture Chat", "Fixture
Bank", `com.example.*` — so that nobody mistakes a screenshot for real captured
data, and so the catalogued issues reproduce identically on every machine.

## Re-capturing

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.signalbox.signalbox/.MainActivity
# load the fixtures from Settings > Developer, then:
adb exec-out screencap -p > docs/screenshots/<name>.png
```
