# Архитектура диспетчеризации заказов Tulpar

Статус: проектирование, реализация не начата. Дата актуализации стоимости:
2026-08-17.

## 1. Цели и границы

Документ описывает один протокол диспетчеризации и две взаимозаменяемые
серверные реализации:

1. Firebase Functions + Cloud Tasks.
2. Собственный backend на VPS.

Flutter не должен знать, какой планировщик создаёт волны. Клиент зависит только
от доменных моделей, `DispatchRepository` и потока серверных событий. SMS,
планировщик, база данных и отправитель FCM находятся за серверной границей.

В текущем проекте эта архитектура ещё не реализована. Документ не меняет
Firestore schema, Rules или существующую Spark-ветку.

## 2. Общий протокол

### 2.1. Состояния заказа

```text
searching -> accepted -> arrived -> in_progress -> completed
     |          |          |
     +----------+----------+-> cancelled
```

Терминальные состояния: `completed`, `cancelled`.

### 2.2. Состояния персонального предложения

```text
active -> accepted
   |----> revoked
   |----> expired
```

`active` означает только право увидеть и попытаться принять заказ. Победитель
определяется серверной транзакцией, а не наличием карточки на устройстве.

### 2.3. Клиентские модели

Одинаковые модели используются обоими адаптерами:

```text
OrderDraft
  clientRequestId
  cityId
  fromAddress / toAddress
  fromLat / fromLng
  toLat / toLng
  offeredPrice

Order
  id
  passengerId
  driverId?
  status
  cityId
  route endpoints
  timestamps
  approachNotificationSentAt?
  revision

DriverOffer
  id
  orderId
  driverId
  wave
  distanceMeters
  status
  visibleFrom
  dispatchVersion

DriverPresence
  driverId
  cityId
  online
  available
  activeOrderId?
  location
  locationUpdatedAt

NotificationEvent
  eventId
  type
  orderId
  createdAt
  payload
```

Все timestamps передаются в UTC ISO-8601. Все изменения содержат `revision`,
чтобы клиент мог игнорировать запоздавшее событие.

### 2.4. Интерфейс Flutter

```dart
abstract interface class DispatchRepository {
  Future<Order> createOrder(OrderDraft draft);
  Stream<Order> watchOrder(String orderId);
  Stream<List<DriverOffer>> watchDriverOffers();
  Future<Order> acceptOffer(String offerId, String requestId);
  Future<Order> transitionOrder(
    String orderId,
    OrderStatus nextStatus,
    String requestId,
  );
  Future<Order> cancelOrder(String orderId, String requestId);
  Future<void> publishDriverPresence(DriverPresenceUpdate update);
  Future<void> registerPushToken(PushToken token);
}
```

Это будущий контракт, а не код для текущего изменения. Реализации:

- `FirebaseDispatchRepository`: callable/HTTPS Functions + Firestore/RTDB
  streams.
- `VpsDispatchRepository`: HTTPS REST + WebSocket/SSE.

UI не вызывает Cloud Tasks, Redis, cron или Firestore transaction напрямую.

### 2.5. Логический API

Транспорт может различаться, но операции и ошибки одинаковы:

| Операция | Команда | Результат |
|---|---|---|
| Создать заказ | `CreateOrder(draft, requestId)` | `Order(searching)` |
| Получать заказ | `WatchOrder(orderId)` | поток снимков `Order` |
| Получать предложения | `WatchDriverOffers(driverId)` | только персональные `DriverOffer` |
| Принять | `AcceptOffer(offerId, requestId)` | назначенный `Order(accepted)` |
| Изменить этап | `TransitionOrder(orderId, nextStatus, requestId)` | обновлённый `Order` |
| Отменить | `CancelOrder(orderId, requestId)` | `Order(cancelled)` |
| Координаты | `PublishDriverLocation(position, sequence)` | подтверждение sequence |
| Push-токен | `RegisterPushToken(token, deviceId)` | регистрация устройства |

Стабильные коды ошибок:

```text
unauthenticated
permission_denied
invalid_argument
order_not_found
order_already_taken
driver_not_available
offer_not_active
invalid_transition
conflict
temporarily_unavailable
```

Каждая изменяющая команда получает UUID `requestId`. Сервер хранит результат
команды и возвращает его при повторе, не выполняя операцию второй раз.

## 3. Волновая выдача

Подходящий водитель должен одновременно:

- быть в том же `cityId`;
- иметь `online == true` и `available == true`;
- не иметь активного заказа;
- иметь свежую геопозицию;
- находиться не дальше `maxDistanceMeters` от точки подачи.

Расстояние для выбора кандидатов считается по прямой (Haversine). Для города
размером около 3 км это дешевле и стабильнее внешнего routing API.

| Момент | Выдача |
|---|---|
| `t = 0`, кандидатов не более 3 | Всем сразу, финальная аудитория открыта |
| `t = 0`, кандидатов больше 3 | Двум ближайшим |
| `t = 12 секунд` | Ещё трём ближайшим, ранее не получавшим заказ |
| `t = 25 секунд` | Всем оставшимся подходящим водителям города |

Волны накопительные. После финальной волны вновь вышедший на линию подходящий
водитель также получает предложение, пока заказ остаётся `searching`.

Серверная конфигурация:

```json
{
  "enabled": true,
  "version": 1,
  "lowSupplyThreshold": 3,
  "firstWaveDriverCount": 2,
  "secondWaveAdditionalCount": 3,
  "secondWaveAfterSeconds": 12,
  "finalWaveAfterSeconds": 25,
  "maxDistanceMeters": 5000,
  "locationFreshnessSeconds": 30,
  "finalWaveIncludesNewDrivers": true
}
```

Каждый заказ сохраняет снимок конфигурации и её версию. Изменение серверной
конфигурации влияет на новые заказы, но не меняет уже запущенные таймеры.

## 4. Вариант A: Firebase Functions + Cloud Tasks

### 4.1. Компоненты

- Firebase Auth либо Firebase Custom Token, выданный SMS-backend на VPS.
- Firestore: заказы, персональные предложения, активные привязки, outbox и
  конфигурация.
- RTDB: частые координаты и presence с `onDisconnect`.
- Callable/HTTPS Functions: все команды общего API.
- Firestore/RTDB triggers: реакция на изменения и outbox.
- Cloud Tasks: волны на `t+12` и `t+25`.
- Firebase Admin SDK: FCM multicast.

Если SMS уже реализован на VPS, рекомендуемый мост — после проверки SMS VPS
создаёт Firebase Custom Token для внутреннего `userId`. Flutter получает
Firebase-сессию и продолжает использовать Firestore streams. Это не требует
двух независимых учётных записей.

### 4.2. Хранение

```text
orders/{orderId}
active_orders/{userId}
order_dispatches/{orderId}
driver_order_offers/{driverId}/orders/{orderId}
driver_states/{driverId}
notification_outbox/{eventId}
server_config/dispatch

RTDB:
driver_locations/{cityId}/{driverId}
```

Клиент не может перечислять все `searching`-заказы. Он читает только свои
offers. Серверный `AcceptOffer` в одной Firestore transaction проверяет заказ,
offer, `driver_states`, active binding пассажира и active binding водителя.

Cloud Task содержит только `orderId`, `wave` и `dispatchVersion`. Повторный
запуск безопасен: task проверяет статус заказа и уже обработанную фазу, а offer
создаётся с детерминированным ID.

### 4.3. Конфигурация

Авторитетную конфигурацию лучше хранить в закрытом `server_config/dispatch`, а
не отдавать Flutter через Remote Config. Function читает её с серверными
правами и кеширует на короткое время. При необходимости истории изменений
сохраняются версионные снимки.

### 4.4. Плюсы и ограничения

Плюсы:

- минимальное администрирование инфраструктуры;
- готовые realtime streams, транзакции, FCM и автоматическое масштабирование;
- быстрый запуск при небольшом числе городов;
- удобная интеграция с текущим Flutter/Firebase кодом.

Ограничения:

- обязателен Blaze и billing account;
- Cloud Tasks и Functions становятся частью доменной инфраструктуры;
- перенос на VPS позже потребует миграции данных, timers и realtime streams;
- Firebase и отдельный SMS-VPS создают две эксплуатационные зоны.

## 5. Вариант B: backend на VPS

### 5.1. Компоненты

- API-сервис: REST-команды и WebSocket/SSE-события.
- SMS-auth и выдача access/refresh JWT.
- PostgreSQL: заказы, offers, транзакции, outbox и конфигурация.
- Redis: presence с TTL, координаты, pub/sub и очередь отложенных задач.
- Worker-процесс: волны, outbox и повторные попытки.
- FCM HTTP v1 через Firebase service account.
- Reverse proxy, TLS, мониторинг, backups.

Для малого запуска допустимы PostgreSQL + Redis + API + worker на одном VPS,
но production backup должен храниться отдельно. При росте компоненты можно
разнести без изменения Flutter API.

### 5.2. Хранение

```text
PostgreSQL:
orders
active_orders
order_dispatches
driver_offers
driver_states
notification_outbox
idempotency_keys
server_config

Redis:
driver:presence:{cityId}
driver:location:{driverId}
dispatch:scheduled
realtime channels
```

PostgreSQL transaction и уникальные ограничения обеспечивают один активный
заказ на пассажира и водителя. `SELECT ... FOR UPDATE` блокирует заказ при
принятии. Redis-предложение никогда не является источником истины: перед
accept сервер проверяет PostgreSQL.

Волны создаются delayed jobs с детерминированным ключом
`dispatch:{orderId}:{wave}`. Worker проверяет `dispatchVersion` и состояние
заказа так же, как Cloud Task.

### 5.3. Конфигурация

Таблица `server_config` хранит JSON policy и версию. Изменение выполняется через
закрытый admin endpoint или административную панель. Backend валидирует
диапазоны и сохраняет audit log. Flutter конфигурацию не загружает.

### 5.4. Плюсы и ограничения

Плюсы:

- SMS, пользователи и диспетчеризация находятся в одной системе;
- нет последующей миграции критической логики с Functions;
- полная свобода SQL-аналитики, геопоиска и администрирования;
- предсказуемая фиксированная базовая стоимость.

Ограничения:

- команда отвечает за обновления ОС, TLS, firewall, backups и мониторинг;
- необходимо самостоятельно обеспечить очередь, retries, WebSocket и HA;
- первоначальная реализация дольше Firebase-варианта;
- один VPS без реплики остаётся точкой отказа.

## 6. Одноразовое уведомление о приближении на 200 метров

### 6.1. Расчёт

Порог хранится в той же серверной конфигурации:

```json
{
  "approachDistanceMeters": 200,
  "approachLocationFreshnessSeconds": 20,
  "approachNotificationEnabled": true
}
```

После принятия заказа каждое принятое сервером положение водителя обрабатывает
серверный proximity-компонент:

1. Загружает активный заказ водителя.
2. Проверяет статус `accepted` или `arrived` и свежесть координат.
3. Считает Haversine distance до `fromLat/fromLng`.
4. Если расстояние больше 200 м, ничего не делает.
5. Если расстояние не больше 200 м и `approachNotificationSentAt == null`,
   атомарно создаёт outbox-event `approach:{orderId}`.

Если водитель уже находился ближе 200 м в момент принятия, событие создаётся
при первой серверной координате. Повторное удаление от пассажира и возвращение
не создаёт второе уведомление.

### 6.2. Идемпотентная отправка

```text
notification_outbox/approach:{orderId}
  eventId
  type = driver_approaching
  orderId
  passengerId
  status = pending | sending | sent | failed
  leaseUntil
  attemptCount
  createdAt
  sentAt?
```

Worker захватывает lease, отправляет FCM и после успешного ответа поставщика в
одной транзакции:

- переводит event в `sent`;
- записывает `sentAt`;
- записывает в заказ `approachNotificationSentAt`.

FCM payload:

```json
{
  "notification": {
    "title": "Водитель рядом",
    "body": "Водитель находится примерно в 200 метрах от точки подачи"
  },
  "data": {
    "type": "driver_approaching",
    "eventId": "approach:{orderId}",
    "orderId": "{orderId}",
    "distanceMeters": "{roundedDistance}"
  }
}
```

Android использует `collapse_key = approach:{orderId}`, APNs — такой же
`apns-collapse-id`. Flutter хранит недавно обработанные `eventId` и повторно не
показывает одинаковое событие.

FCM не гарантирует физическую exactly-once доставку: процесс может завершиться
между отправкой и записью `sentAt`. Детерминированный outbox-event, lease,
collapse key и клиентская дедупликация дают идемпотентное пользовательское
поведение. `approachNotificationSentAt` означает, что FCM принял хотя бы одну
отправку, а не что устройство гарантированно показало уведомление.

### 6.3. Поведение Flutter

- Foreground: `NotificationRouter` показывает один неблокирующий banner или
  SnackBar и предлагает открыть текущий заказ.
- Background: системное notification открывает `OrderTrackingScreen` по нажатию.
- Terminated: initial message сохраняется до завершения auth/splash bootstrap,
  затем открывается активный заказ. Splash не должен перезаписывать этот route.
- Любое состояние: `type` маршрутизируется явно; `driver_approaching` не должно
  открывать чат.

## 7. Тесты общего протокола

### 7.1. Серверные contract tests

Один набор JSON fixtures запускается для Firebase и VPS:

- при 0–3 кандидатах offer получают все сразу;
- при 4+ кандидатах первая волна содержит двух ближайших;
- в `t+12` добавляются максимум три новых водителя;
- в `t+25` добавляются все оставшиеся;
- водитель другого города или дальше максимума исключается;
- stale/offline/busy водитель исключается перед каждой волной;
- повтор task/job не создаёт дубликаты offers;
- принятие одним водителем закрывает возможность принятия другим;
- повтор команды с тем же `requestId` возвращает прежний результат;
- завершённый или отменённый заказ останавливает волны;
- отмена и завершение освобождают водителя атомарно.

### 7.2. Тесты приближения

- 201 м: outbox не создаётся;
- 200 и 199 м: создаётся ровно один event;
- параллельные location updates создают один `approach:{orderId}`;
- существующий `approachNotificationSentAt` блокирует повтор;
- retry после ошибки FCM использует тот же `eventId`;
- отменённый/completed заказ не отправляет уведомление;
- stale location не запускает уведомление;
- invalid FCM token удаляется, остальные устройства получают событие;
- `approachNotificationSentAt` записывается только после успешной отправки.

### 7.3. Flutter tests

- foreground event показывает сообщение один раз;
- повтор того же `eventId` игнорируется;
- background tap открывает правильный `OrderTrackingScreen`;
- terminated event ждёт окончания bootstrap и затем открывает заказ;
- splash выполняет только одну итоговую навигацию;
- событие другого пользователя или неактивного заказа игнорируется;
- FCM `onMessage`, `onMessageOpenedApp`, token refresh и auth subscriptions
  закрываются при dispose и не дублируются после повторной инициализации.

Firebase Emulator и mock FCM проверяют бизнес-логику, но foreground/background/
terminated дополнительно требуют smoke tests на реальном Android-устройстве.

## 8. Стоимость

Цены ниже — ориентиры без SMS и налогов; перед запуском их нужно пересчитать
для выбранного региона.

### Firebase

- Blaze обязателен для Functions.
- Cloud Run functions: первые 2 млн вызовов в месяц входят в free tier, далее
  указана цена $0.40 за миллион вызовов; отдельно учитываются compute, build,
  registry и egress.
- Cloud Tasks: первый 1 млн операций в месяц бесплатно, далее $0.40 за миллион.
- Firestore: free quota включает 50 тыс. reads и 20 тыс. writes/deletes в день,
  1 GiB хранения и 10 GiB egress в месяц.
- FCM не тарифицируется.

Для одного-нескольких небольших городов без warm instances вычислительная
часть часто укладывается в free tier, но billing account всё равно обязателен.
Практический бюджет: примерно $0–10/месяц плюс SMS, логи, egress и возможное
хранение container images. Если SMS-VPS уже нужен, оплачивается также VPS.

Официальные источники:

- [Cloud Run functions pricing](https://cloud.google.com/functions/pricing-1stgen)
- [Cloud Tasks pricing](https://cloud.google.com/tasks/pricing)
- [Firebase pricing](https://firebase.google.com/pricing)
- [Firestore billing](https://firebase.google.com/docs/firestore/pricing)

### VPS

Небольшой VPS начинается примерно с $6/месяц за 1 GiB RAM у DigitalOcean;
после объявленного на июнь 2026 изменения Hetzner CX23 указан около €5.49 в
месяц без VAT и отдельного IPv4. Для API + PostgreSQL + Redis + worker разумнее
начинать с 2 GiB RAM: ориентир $12–20/месяц. Backups обычно добавляют около
20–30%, внешний мониторинг и объектное хранилище оплачиваются отдельно.

Реалистичные диапазоны:

- один VPS без HA: $10–40/месяц плюс SMS;
- отдельная база/backups/monitoring: $30–80/месяц;
- два узла и управляемая база для HA: от $60–150/месяц.

Официальные ориентиры:

- [DigitalOcean Droplet pricing](https://www.digitalocean.com/pricing/droplets)
- [Hetzner cloud price adjustment, June 2026](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/)

Главная стоимость VPS — не CPU, а время на эксплуатацию и восстановление после
сбоев.

## 9. Миграция и переиспользование

| Часть | Переиспользуется |
|---|---|
| Flutter domain models и `DispatchRepository` | Полностью |
| Экраны заказа, offers и tracking | Полностью |
| JSON fixtures и contract tests | Полностью |
| Статусы, переходы и error codes | Полностью |
| Формула волн и Haversine | Полностью концептуально; код зависит от языка |
| FCM payload, eventId и клиентская дедупликация | Полностью |
| Outbox/idempotency protocol | Полностью концептуально |
| Firestore documents, Rules, listeners | Только Firebase |
| Cloud Tasks/triggers | Только Firebase |
| PostgreSQL schema, Redis и WebSocket gateway | Только VPS |

### Firebase -> VPS позднее

Сложность миграции средняя/высокая. Flutter меняет только adapter, если контракт
соблюдён, но нужно перенести активные данные, offers, idempotency keys,
планировщик и realtime transport. Без общего контракта миграция станет полной
переработкой.

### VPS сразу

Начальная сложность выше, но SMS-auth и dispatch создаются один раз. Это
предпочтительно, если VPS уже является утверждённой production-платформой и у
команды есть ответственность за его круглосуточную эксплуатацию.

### Переходный вариант

Если SMS-backend появится раньше решения о диспетчеризации, VPS может выдавать
Firebase Custom Token после SMS-проверки. Тогда идентификатор пользователя уже
будет единым, а выбор Firebase/VPS dispatch можно отложить без создания второй
системы аккаунтов.

## 10. Критерий выбора

Выбирать Firebase следует, если приоритет — быстрее запустить выдачу и снизить
операционную нагрузку, а VPS пока не является надёжной production-платформой.

Выбирать VPS следует, если SMS-backend уже точно будет работать 24/7, команда
готова обслуживать PostgreSQL/Redis/backups и важно сразу держать auth,
диспетчеризацию и аудит в одной системе.

До выбора варианта можно безопасно реализовать только общий Dart-контракт,
DTO, error codes, notification routing и общий набор contract fixtures. Сам
планировщик и хранилище следует реализовывать один раз после архитектурного
решения.
