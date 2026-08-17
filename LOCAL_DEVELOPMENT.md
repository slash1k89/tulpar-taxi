# Бесплатный локальный режим Firebase

Этот режим использует Firebase Emulator Suite и не обращается к production
данным `taxi-esil`. Он включается только через `--dart-define`.

## 1. Запустите эмуляторы

В первом PowerShell-окне, из корня проекта:

```powershell
npx -y firebase-tools@latest emulators:start --project taxi-esil
```

Firebase Emulator UI откроется на `http://127.0.0.1:4000`. Локальные порты:

- Authentication — `9099`
- Cloud Firestore — `8080`
- Realtime Database — `9000`
- Cloud Functions — `5001`

## 2. Запустите Android-эмулятор

Во втором окне:

```powershell
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
```

По умолчанию Android Emulator подключается к компьютеру через `10.0.2.2`.
Для физического Android-устройства выполните:

```powershell
adb reverse tcp:9099 tcp:9099
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9000 tcp:9000
adb reverse tcp:5001 tcp:5001
flutter run --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

## 3. Проверьте в Emulator UI

1. Зарегистрируйте тестового пассажира и тестового водителя.
2. Убедитесь, что пользователи и заказы появились в Auth и Firestore.
3. Включите водителю «На линии», примите заказ и проверьте Functions logs.
4. Проверьте RTDB `active_order_locations` во время активной поездки и её
   удаление после отмены или завершения.

## Ограничения локального режима

- Реальные FCM push-уведомления Emulator Suite не отправляет.
- SMS/Phone Authentication не проверяется локально; в приложении сейчас
  используется email/password, сформированный из номера телефона.
- Данные Emulator Suite локальные и удаляются после остановки, если не
  включать отдельный import/export данных.
