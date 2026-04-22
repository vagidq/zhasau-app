# Zhasau App — Setup Guide

Инструкция как поднять проект с нуля на новой машине.

## Содержание
- [Требования](#требования)
- [1. Клонирование репо](#1-клонирование-репо)
- [2. Flutter зависимости](#2-flutter-зависимости)
- [3. Firebase конфиги (секреты)](#3-firebase-конфиги-секреты)
- [4. Android setup](#4-android-setup)
- [5. iOS setup](#5-ios-setup)
- [6. Запуск](#6-запуск)
- [Troubleshooting](#troubleshooting)

---

## Требования

| Инструмент | Версия |
|---|---|
| Flutter | `>=3.24` (stable) |
| Dart | `>=3.0 <4.0` |
| Android SDK | API 33+ (Tiramisu) с Google Play Services |
| Xcode | 15+ (только для iOS разработчиков) |
| Java | 17 |

Проверка:
```bash
flutter doctor
```

---

## 1. Клонирование репо

```bash
git clone https://github.com/vagidq/zhasau-app.git
cd zhasau-app
```

---

## 2. Flutter зависимости

```bash
flutter pub get
```

---

## 3. Firebase конфиги (секреты)

Три файла **НЕ в git** (см. `.gitignore`), их нужно получить:

```
android/app/google-services.json          ⚠️ отсутствует
ios/Runner/GoogleService-Info.plist       ⚠️ отсутствует
firebase.json                             ⚠️ отсутствует (опционально)
```

### Варианты как получить

**Вариант A — через Firebase Console (рекомендую)**

1. Попросить владельца проекта добавить тебя в Firebase → `goal-planner`
2. Открыть https://console.firebase.google.com/project/goal-planner-c7cbf/settings/general
3. Раздел **Your apps** → найти `zhasau_app (android)` → нажать **google-services.json** → скачать
4. Положить в: `android/app/google-services.json`
5. Найти `zhasau_app (ios)` → нажать **GoogleService-Info.plist** → скачать
6. Положить в: `ios/Runner/GoogleService-Info.plist` (потом ещё добавить в Xcode target, см. iOS setup)

**Вариант B — попросить у команды**

Запросить 2 файла у любого разработчика (в приватном канале, не в чате/PR!).

**Вариант C — через FlutterFire CLI**

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=goal-planner-c7cbf
```

Автоматически скачает оба файла и положит в правильные места. Интерактив:
- Platforms: выбрать **android + ios** (пробелом)
- Overwrite `lib/firebase_options.dart` → **yes**

---

## 4. Android setup

### 4.1. Получить SHA-1 своего debug keystore

```bash
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android \
  -keypass android | grep SHA1
```

Если выдаст ошибку «keystore not found» — создай его:

```bash
keytool -genkey -v \
  -keystore ~/.android/debug.keystore \
  -storepass android \
  -alias androiddebugkey \
  -keypass android \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Android Debug,O=Android,C=US"
```

Затем повтори предыдущую команду. Скопируй строку вида:
```
SHA1: 61:55:FA:83:3C:99:DA:59:...
```

### 4.2. Добавить SHA-1 в Firebase

1. Firebase Console → Project settings → `zhasau_app (android)` → **Add fingerprint**
2. Вставить SHA-1 → Save
3. **Снова скачать `google-services.json`** (обновлённый) и заменить в `android/app/`

Без этого Google Sign-In выдаст `ApiException: 10` (DEVELOPER_ERROR).

### 4.3. Запуск эмулятора

Создай **Android 13 (API 33) Google Play** эмулятор через Android Studio → Device Manager → **+ Create Virtual Device** → Pixel 7 → **Tiramisu API 33 Google Play** → Finish.

⚠️ Обязательно **Google Play** (не просто Google APIs) — иначе нет Google Play Services для Sign-In.

---

## 5. iOS setup

_Только если работаешь с iOS сборкой._

### 5.1. Добавить `GoogleService-Info.plist` в Xcode target

`ios/Runner/GoogleService-Info.plist` **недостаточно положить в папку** — Xcode не увидит.

```bash
open ios/Runner.xcworkspace
```

В левой панели Xcode: раскрой **Runner → Runner** → перетащи `GoogleService-Info.plist` из Finder.

В диалоге:
- ☑ Copy items if needed
- ☑ Add to targets: **Runner**

Cmd+S.

Либо использовать `flutterfire configure` (Вариант C выше) — оно прописывает в Xcode автоматически.

### 5.2. CocoaPods

```bash
cd ios
pod install
cd ..
```

---

## 6. Запуск

Проверь что есть девайс:
```bash
flutter devices
```

Должен быть хотя бы один из:
- `emulator-5554` (Android)
- `iPhone 15 Pro Simulator` (iOS)
- реальный девайс по USB

Запуск:
```bash
flutter run
```

Если несколько девайсов — Flutter спросит какой. Или явно:
```bash
flutter run -d emulator-5554
```

---

## Troubleshooting

### Gradle timeout при первой сборке

Симптом:
```
java.net.SocketException: Operation timed out
at org.gradle.wrapper.Download.downloadInternal
```

Причины: `services.gradle.org` заблокирован провайдером / требует VPN.

**Фикс**: временно подменить зеркало в `android/gradle/wrapper/gradle-wrapper.properties`:
```properties
distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-8.14-all.zip
```

⚠️ Не коммить этот файл с локальным зеркалом. Используй:
```bash
git update-index --skip-worktree android/gradle/wrapper/gradle-wrapper.properties
```

### `ApiException: 10` (DEVELOPER_ERROR) на Android

SHA-1 не пробросился в Firebase → см. шаг 4.2.

### `ApiException: 12500` на Android

Эмулятор без Google Play Services. Создай новый эмулятор с образом **Google Play** (не Google APIs).

### Эмулятор не видит интернет (`UnknownHostException`)

1. Выключи VPN на Mac (Cloudflare WARP, V2rayU, любой)
2. Или запускай эмулятор с явным DNS:
```bash
~/Library/Android/sdk/emulator/emulator -avd Pixel_7_API_33 -dns-server 8.8.8.8,8.8.4.4 &
```

### Google Sign-In → «access_denied»

Email не в Test users OAuth Consent Screen. Попроси добавить:
- https://console.cloud.google.com/auth/audience?project=goal-planner-c7cbf
- **Test users → Add users** → вставить email

### `adb: command not found`

Android platform-tools не в PATH. Добавь в `~/.zshrc`:
```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"
```
```bash
source ~/.zshrc
```

### Чёрный экран на Pixel Fold эмуляторе

Pixel Fold — раскладной (квадратный экран в unfolded режиме). Приложение работает в portrait only.

Фикс: создай обычный **Pixel 7** эмулятор (см. 4.3).

---

## Быстрый чек-лист

- [ ] `git clone ...`
- [ ] `flutter pub get`
- [ ] `android/app/google-services.json` на месте
- [ ] `ios/Runner/GoogleService-Info.plist` на месте (+ в Xcode target)
- [ ] SHA-1 моего debug keystore добавлен в Firebase
- [ ] Свежий `google-services.json` перескачан после добавления SHA-1
- [ ] Эмулятор Android 13 Google Play создан и запущен
- [ ] `flutter run` работает

---

## Полезные команды

```bash
# Перегенерировать все конфиги Firebase
flutterfire configure --project=goal-planner-c7cbf

# Очистить всё и пересобрать
flutter clean && flutter pub get

# Проверить код (без ошибок должно быть 0 errors, info/warnings ок)
flutter analyze

# Запуск на конкретном устройстве
flutter run -d <device-id>

# Логи от запущенного приложения
flutter logs
```

---

## Контакты

Если что-то не работает — создавай issue в репо или пиши в команду.
