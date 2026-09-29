// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get loginTitle => 'Авторизация';

  @override
  String get verificationTitle => 'Подтверждение номера';

  @override
  String get profileTitle => 'Как к вам обращаться?';

  @override
  String get phoneHint =>
      'На ваш номер поступит короткий звонок.\nВведите последние 4 цифры номера звонящего.';

  @override
  String get codeHint => 'Введите последние 4 цифры номера входящего звонка';

  @override
  String get profileHint => 'Имя будет отображаться в вашем профиле.';

  @override
  String get requestCode => 'Получить код звонком';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get continueLabel => 'Продолжить';

  @override
  String resendIn(int seconds) {
    return 'Позвонить ещё раз через $seconds сек.';
  }

  @override
  String get resend => 'Позвонить ещё раз';

  @override
  String get phoneNumber => 'Номер телефона';

  @override
  String get lastFourDigits => 'Последние 4 цифры';

  @override
  String get nameLabel => 'Имя';

  @override
  String get invalidPhone => 'Введите корректный номер телефона.';

  @override
  String get invalidCode => 'Введите последние 4 цифры номера звонящего.';

  @override
  String get invalidName => 'Введите имя длиной от 2 до 120 символов.';

  @override
  String get resendCooldown => 'Повторный звонок пока недоступен.';

  @override
  String get checkPhone => 'Проверьте номер телефона.';

  @override
  String get invalidVerification => 'Неверный или просроченный код.';

  @override
  String get loginFailed => 'Не удалось выполнить вход. Попробуйте ещё раз.';

  @override
  String get serverTimeout => 'Сервер не ответил. Попробуйте ещё раз.';

  @override
  String get chooseLanguage => 'Выбрать язык';

  @override
  String get languageSetting => 'Язык';

  @override
  String get registerTitle => 'Регистрация';

  @override
  String get createAccount => 'Создание аккаунта';

  @override
  String get registerButton => 'Зарегистрироваться';

  @override
  String get authSignIn => 'Войти';

  @override
  String get authForgotPassword => 'Забыли пароль?';

  @override
  String get authResetPasswordTitle => 'Восстановление пароля';

  @override
  String get authCreatePasswordTitle => 'Создайте пароль';

  @override
  String get authVerificationPhoneHint =>
      'Укажите номер для подтверждения звонком.';

  @override
  String get authPasswordTooShort =>
      'Пароль должен содержать не менее 8 символов.';

  @override
  String get authInvalidCredentials => 'Неверный номер телефона или пароль.';

  @override
  String get authPasswordAlreadySet =>
      'Пароль уже установлен. Воспользуйтесь восстановлением.';

  @override
  String get authVerificationRequired => 'Подтвердите номер ещё раз.';

  @override
  String get authBackToLogin => 'Назад ко входу';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get confirmPassword => 'Повторите пароль';

  @override
  String get enterName => 'Введите имя';

  @override
  String get nameTooLong => 'Имя слишком длинное';

  @override
  String get enterPhone => 'Введите номер телефона';

  @override
  String get enterFullPhone => 'Введите номер полностью';

  @override
  String get enterPassword => 'Введите пароль';

  @override
  String get shortPassword => 'Пароль должен содержать минимум 6 символов';

  @override
  String get passwordMismatch => 'Пароли не совпадают';

  @override
  String registrationSuccess(String phone) {
    return 'Пользователь зарегистрирован: $phone';
  }

  @override
  String get pushOpen => 'Открыть';

  @override
  String get pushDriverApproachingTitle => 'Водитель скоро будет на месте';

  @override
  String get pushDriverApproachingBody =>
      'Пожалуйста, выходите к месту подачи — водитель уже подъезжает.';

  @override
  String get pushNewMessage => 'Новое сообщение в чате';

  @override
  String get pushOrderAccepted => 'Водитель едет к вам';

  @override
  String get pushDeliveryAccepted => 'Курьер едет за посылкой';

  @override
  String get pushDriverArrived => 'Водитель на месте и ожидает вас!';

  @override
  String get pushDeliveryArrived => 'Курьер прибыл за посылкой';

  @override
  String get pushTripStarted => 'Поездка началась';

  @override
  String get pushDeliveryStarted => 'Посылка в пути';

  @override
  String get pushTripCompleted => 'Поездка завершена!';

  @override
  String get pushDeliveryCompleted => 'Доставка завершена';

  @override
  String get pushOrderCancelled => 'Заказ отменён';

  @override
  String get pushNewDriverOrder => 'Новый заказ';

  @override
  String get pushDriverHeading => 'Водитель направляется к месту подачи.';

  @override
  String get pushIntercityMatch => 'Появилась подходящая попутка';

  @override
  String get pushIntercityCancelled => 'Водитель отменил попутку';

  @override
  String get pushIntercityDeparted => 'Попутка отправилась';

  @override
  String get pushIntercityBooked => 'Новое бронирование попутки';

  @override
  String get pushIntercityBookingCancelled => 'Бронирование попутки отменено';

  @override
  String get serviceCity => 'Такси';

  @override
  String get serviceDelivery => 'Доставка';

  @override
  String get serviceIntercity => 'Межгород';

  @override
  String get driverCityOrders => 'Заказы такси';

  @override
  String get driverDeliveryOrders => 'Заказы доставки';

  @override
  String driverNewOrder(String service) {
    return 'Новый заказ — $service';
  }

  @override
  String get statusSearchingDriver => 'Поиск свободного водителя...';

  @override
  String get statusSearchingCourier => 'Поиск свободного курьера...';

  @override
  String get statusSearchingIntercity => 'Поиск водителя для межгорода...';

  @override
  String get statusCourierComing => 'Курьер едет за посылкой';

  @override
  String get statusDriverComing => 'Водитель едет к вам';

  @override
  String get statusCourierArrived => 'Курьер прибыл за посылкой';

  @override
  String get statusDriverArrived => 'Водитель на месте и ожидает вас!';

  @override
  String get statusIntercityDriverArrived => 'Водитель прибыл';

  @override
  String get statusHandPackage => 'Передайте посылку курьеру';

  @override
  String get statusGoToCar => 'Пожалуйста, выходите к автомобилю';

  @override
  String get statusPackageOnWay => 'Посылка в пути';

  @override
  String get statusTripInProgress => 'Поездка в процессе';

  @override
  String get statusTripStarted => 'Поездка началась';

  @override
  String get statusDeliveryCompleted => 'Доставка завершена';

  @override
  String get statusTripCompleted => 'Поездка завершена!';

  @override
  String get statusIntercityCompleted => 'Междугородняя поездка завершена';

  @override
  String get statusDriverFinishingPrevious =>
      'Водитель завершает предыдущую поездку';

  @override
  String get cancelOrderTitle => 'Отмена заказа';

  @override
  String get confirmCancelOrder => 'Вы уверены, что хотите отменить заказ?';

  @override
  String get no => 'Нет';

  @override
  String get yesCancel => 'Да, отменить';

  @override
  String offerAccepted(String driver, String price) {
    return '$driver: предложение $price ₸ принято.';
  }

  @override
  String get close => 'Закрыть';

  @override
  String get cancelOrderFailed =>
      'Не удалось отменить заказ. Проверьте соединение и повторите попытку.';

  @override
  String get yourOrder => 'Ваш заказ';

  @override
  String get orderCancelled => 'Заказ отменён';

  @override
  String get orderLoadFailed => 'Ошибка загрузки данных заказа';

  @override
  String get invalidOrderCoordinates => 'Некорректные координаты заказа';

  @override
  String get cancelling => 'Отмена...';

  @override
  String get cancelSearch => 'Отменить поиск';

  @override
  String get queuedOrderHint =>
      'После завершения водитель сразу направится к вам.';

  @override
  String get cancelOrder => 'Отменить заказ';

  @override
  String recipientAddress(String address) {
    return 'Адрес получателя: $address';
  }

  @override
  String directionAddress(String address) {
    return 'Направление: $address';
  }

  @override
  String get addressUnknown => 'Адрес не указан';

  @override
  String orderStatusUnknown(String status) {
    return 'Статус заказа: $status';
  }

  @override
  String get cancel => 'Отменить';

  @override
  String get courier => 'Курьер';

  @override
  String get driver => 'Водитель';

  @override
  String get car => 'Автомобиль';

  @override
  String fromAddress(String address) {
    return 'Откуда: $address';
  }

  @override
  String toAddress(String address) {
    return 'Куда: $address';
  }

  @override
  String priceTenge(String price) {
    return 'Стоимость: $price ₸';
  }

  @override
  String get carLoading => 'Данные машины загружаются...';

  @override
  String get driverProfile => 'Профиль водителя';

  @override
  String get chat => 'Чат';

  @override
  String get taxiAndDelivery => 'Такси и доставка';

  @override
  String get chatInvalidLength =>
      'Сообщение должно содержать от 1 до 2000 символов.';

  @override
  String get chatInvalidRequest => 'Ошибка в данных или параметрах запроса.';

  @override
  String get chatForbidden => 'У вас нет доступа к этому заказу.';

  @override
  String get chatOrderNotFound => 'Заказ не найден.';

  @override
  String get chatSendFailed => 'Не удалось отправить сообщение.';

  @override
  String chatRateLimited(int seconds) {
    return 'Слишком много сообщений. Повторите через $seconds сек.';
  }

  @override
  String get retry => 'Повторить';

  @override
  String get chatEmpty => 'Нет сообщений. Напишите первым!';

  @override
  String get chatMessageHint => 'Сообщение...';

  @override
  String get mapDeliveryPriceRequired => 'Укажите цену доставки.';

  @override
  String get mapTripPriceRequired => 'Укажите цену поездки.';

  @override
  String get mapLocationSlow =>
      'Не удалось быстро определить местоположение. Выберите адрес вручную.';

  @override
  String mapOutsideCity(String city) {
    return 'Ваше местоположение вне города $city.';
  }

  @override
  String mapChoosePointInCity(String city) {
    return 'Выберите точку в городе $city.';
  }

  @override
  String get mapResolvingAddress => 'Определение адреса...';

  @override
  String get mapChoosePointInKazakhstan =>
      'Выберите точку на территории Казахстана.';

  @override
  String get mapPickupCity => 'Город отправления';

  @override
  String get mapDestinationCity => 'Город назначения';

  @override
  String get mapChooseCity => 'Выберите город';

  @override
  String get mapRouteFailed =>
      'Не удалось построить маршрут. Попробуйте ещё раз.';

  @override
  String get mapChooseFutureTime => 'Выберите будущее время.';

  @override
  String get mapChooseBothCities =>
      'Сначала выберите города отправления и назначения.';

  @override
  String get mapChooseRoutePoints =>
      'Укажите точки A и B на карте или выберите их из списка.';

  @override
  String get mapPointA => 'Точка A';

  @override
  String get mapPointB => 'Точка B';

  @override
  String get mapServerTimeout => 'Нет ответа от сервера. Попробуйте ещё раз.';

  @override
  String get mapStaleOrder =>
      'Найдена устаревшая привязка заказа. Она не удалена автоматически. Обратитесь к администратору для проверки.';

  @override
  String mapServiceInCity(String service, String city) {
    return '$service — $city';
  }

  @override
  String get mapExactPickupAddress => 'Точный адрес отправления';

  @override
  String get mapChooseAddress => 'Выберите адрес';

  @override
  String get mapExactDeliveryAddress => 'Точный адрес доставки';

  @override
  String get mapExactDestinationAddress => 'Точный адрес назначения';

  @override
  String get mapRecipientApartment => 'Квартира получателя (необязательно)';

  @override
  String get mapPackageDescription => 'Описание посылки';

  @override
  String get mapPackageExample => 'Например: документы';

  @override
  String get mapRecipientName => 'Имя получателя';

  @override
  String get mapRecipientPhone => 'Телефон получателя';

  @override
  String get mapPassengerCount => 'Количество пассажиров';

  @override
  String get mapHasLuggage => 'Есть багаж';

  @override
  String get mapOptionalComment => 'Комментарий (необязательно)';

  @override
  String get mapYourPrice => 'Ваша цена (₸)';

  @override
  String get mapRequestDelivery => 'Заказать доставку';

  @override
  String get mapRequestIntercity => 'Заказать межгород';

  @override
  String get mapRequestTaxi => 'Заказать такси';

  @override
  String get orderErrorLogin => 'Войдите в аккаунт и повторите попытку.';

  @override
  String get orderErrorActive => 'У вас уже есть активный заказ.';

  @override
  String get orderErrorInvalid => 'Проверьте адреса, цену и точки маршрута.';

  @override
  String get orderErrorDelivery =>
      'Заполните описание посылки, имя и телефон получателя.';

  @override
  String get orderErrorIntercity =>
      'Проверьте время и данные междугородней поездки.';

  @override
  String get orderErrorPermission => 'Нет доступа к созданию заказа.';

  @override
  String get orderErrorUnavailable =>
      'Нет связи с сервером. Попробуйте ещё раз.';

  @override
  String get orderErrorUnknown =>
      'Не удалось создать заказ. Попробуйте ещё раз.';

  @override
  String get driverAcceptDelivery =>
      'Доставка принята! Направляйтесь за посылкой.';

  @override
  String get driverAcceptIntercity =>
      'Междугородняя поездка принята! Направляйтесь к пассажиру.';

  @override
  String get driverAcceptCity => 'Заказ принят! Направляйтесь к клиенту.';

  @override
  String get driverAcceptFailed =>
      'Не удалось принять заказ. Попробуйте ещё раз.';

  @override
  String get driverProposePrice => 'Предложить цену';

  @override
  String get driverSendOffer => 'Отправить';

  @override
  String get pickerResolvingAddress => 'Определение адреса...';

  @override
  String get pickerAddressUnavailable =>
      'Не удалось определить адрес. Координаты сохранены.';

  @override
  String get pickerAddressTimeout =>
      'Сервис адресов не отвечает. Координаты сохранены.';

  @override
  String pickerCoordinate(String latitude, String longitude) {
    return 'Точка на карте ($latitude, $longitude)';
  }

  @override
  String pickerChooseInCity(String city) {
    return 'Выберите точку в городе $city.';
  }

  @override
  String get pickerCityCheckFailed =>
      'Не удалось проверить город. Проверьте сеть и повторите.';

  @override
  String get pickerPointCheckFailed =>
      'Не удалось проверить точку. Попробуйте ещё раз.';

  @override
  String get pickerEnableLocation => 'Включите геолокацию на телефоне.';

  @override
  String get pickerLocationDenied => 'Доступ к геолокации не разрешён.';

  @override
  String get pickerLocationSettings =>
      'Разрешите геолокацию в настройках приложения.';

  @override
  String get pickerLocationSlow =>
      'Не удалось быстро определить местоположение. Выберите точку вручную.';

  @override
  String get pickerLocationFailed =>
      'Не удалось определить местоположение. Выберите точку вручную.';

  @override
  String get pickerNoLocation =>
      'Не удалось получить местоположение. Выберите точку вручную.';

  @override
  String get pickerCityCheckManual =>
      'Не удалось проверить город. Выберите точку вручную или повторите.';

  @override
  String get pickerPickupTitle => 'Точка отправления';

  @override
  String get pickerDestinationTitle => 'Точка назначения';

  @override
  String get pickerMyLocation => 'Моё местоположение';

  @override
  String get pickerChecking => 'Проверка...';

  @override
  String get pickerChoosePoint => 'Выбрать эту точку';

  @override
  String get profileNotAuthenticated => 'Пользователь не авторизован';

  @override
  String get profileLoadFailed => 'Не удалось загрузить профиль';

  @override
  String get profileSaved => 'Профиль сохранён';

  @override
  String get profileLegacyError =>
      'Профиль имеет старый формат. Если после заполнения имени ошибка повторится, проверьте uid, телефон, роль и дату создания в Firebase.';

  @override
  String profileSaveCodeError(String code) {
    return 'Не удалось сохранить профиль: $code.';
  }

  @override
  String get profileSaveFailed => 'Не удалось сохранить профиль.';

  @override
  String get profileDeleteTitle => 'Удалить аккаунт?';

  @override
  String get profileDeleteFinalTitle => 'Точно удалить аккаунт?';

  @override
  String get profileDeleteWarning =>
      'Это действие необратимо. Активные заказы и поездки необходимо сначала завершить или отменить.';

  @override
  String get profileDeleteFinalWarning =>
      'После продолжения восстановить аккаунт и личные данные будет невозможно.';

  @override
  String get profileYesDelete => 'Да, удалить';

  @override
  String get profileDeleteCallRequired =>
      'Для удаления аккаунта потребуется повторное подтверждение звонком.';

  @override
  String get profileDeleted => 'Аккаунт удалён.';

  @override
  String get profileDeletionPending =>
      'Запрос на удаление принят. Завершение удаления может занять некоторое время.';

  @override
  String get profileDeleteFailed => 'Не удалось удалить аккаунт.';

  @override
  String get profileSettingsTitle => 'Профиль и настройки';

  @override
  String get profileName => 'Имя';

  @override
  String get profileEnterName => 'Введите имя';

  @override
  String get profileNameTooLong => 'Имя слишком длинное';

  @override
  String get profilePhone => 'Номер телефона';

  @override
  String get profilePhoneReadonly => 'Номер телефона нельзя изменить';

  @override
  String get profileCar => 'Марка и модель авто';

  @override
  String get profileTheme => 'Тема';

  @override
  String get profileThemeSystem => 'Как в системе';

  @override
  String get profileThemeLight => 'Светлая';

  @override
  String get profileThemeDark => 'Тёмная';

  @override
  String get profileVoice => 'Голосовые подсказки';

  @override
  String get profileVoiceHint => 'Озвучивать манёвры во время навигации';

  @override
  String get profileSave => 'Сохранить данные';

  @override
  String get profilePasswordTitle => 'Подтвердите пароль';

  @override
  String get profileCurrentPassword => 'Текущий пароль';

  @override
  String get profileEnterPassword => 'Введите пароль';

  @override
  String unreadMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сообщений',
      many: '$count сообщений',
      few: '$count сообщения',
      one: '$count сообщение',
      zero: '0 сообщений',
    );
    return '$_temp0';
  }

  @override
  String get agreementSaveFailed =>
      'Не удалось сохранить согласие. Попробуйте ещё раз.';

  @override
  String get agreementRulesTitle => 'Правила работы водителя';

  @override
  String agreementVersion(String version) {
    return 'Соглашение версии $version';
  }

  @override
  String get agreementBody =>
      'Переходя в режим водителя, я подтверждаю, что:\n\n• имею право управлять автомобилем и использую технически исправный автомобиль;\n\n• соблюдаю правила дорожного движения и требования безопасности;\n\n• поддерживаю автомобиль в чистоте и вежливо общаюсь с пассажирами;\n\n• не выхожу на линию в состоянии, которое мешает безопасному управлению;\n\n• указываю достоверные сведения об автомобиле и не передаю аккаунт другим лицам;\n\n• использую данные пассажира только для выполнения заказа.';

  @override
  String get agreementConfirm => 'Я прочитал(а) правила и принимаю соглашение';

  @override
  String get agreementAcceptContinue => 'Принять и продолжить';

  @override
  String get onboardingLoginRequired =>
      'Войдите в аккаунт, чтобы включить режим водителя.';

  @override
  String get onboardingServerTimeout =>
      'Сервер не ответил. Проверьте интернет и повторите попытку.';

  @override
  String get onboardingLoadFailed => 'Не удалось загрузить профиль водителя.';

  @override
  String get onboardingActivated => 'Профиль водителя активирован';

  @override
  String get onboardingRetryTimeout => 'Сервер не ответил. Попробуйте ещё раз.';

  @override
  String get onboardingSubmitFailed => 'Не удалось отправить заявку водителя.';

  @override
  String get onboardingPermissionDenied =>
      'Недостаточно прав для изменения водительского профиля.';

  @override
  String get onboardingUnavailable =>
      'Сервис временно недоступен. Проверьте интернет.';

  @override
  String onboardingFirebaseError(String code) {
    return 'Ошибка Firebase: $code. Попробуйте ещё раз.';
  }

  @override
  String get onboardingPendingTitle =>
      'Заявка водителя отправлена на проверку.';

  @override
  String get onboardingPendingBody =>
      'После одобрения режим водителя станет доступен автоматически. Соглашение и данные автомобиля повторно заполнять не нужно.';

  @override
  String get onboardingCheckStatus => 'Проверить статус';

  @override
  String get onboardingSuspendedTitle => 'Доступ водителя приостановлен.';

  @override
  String get onboardingSuspendedBody =>
      'Вы пока не можете принимать заказы. Для уточнения причины обратитесь к администратору MEKEN.';

  @override
  String get onboardingCheckAgain => 'Проверить снова';

  @override
  String get onboardingDriverMode => 'Режим водителя';

  @override
  String get onboardingVehicleTitle => 'Автомобиль водителя';

  @override
  String get onboardingFillVehicle => 'Заполните данные автомобиля';

  @override
  String get onboardingVehicleHint =>
      'После отправки заявка перейдёт на проверку. Эти сведения увидит пассажир только после принятия заказа.';

  @override
  String get onboardingCarModel => 'Марка и модель';

  @override
  String get onboardingCarModelRequired => 'Укажите марку и модель автомобиля';

  @override
  String get onboardingCarColor => 'Цвет кузова';

  @override
  String get onboardingCarColorRequired => 'Укажите цвет автомобиля';

  @override
  String get onboardingCarNumber => 'Государственный номер';

  @override
  String get onboardingCarNumberRequired => 'Укажите государственный номер';

  @override
  String get onboardingSubmit => 'Отправить заявку на проверку';

  @override
  String get drawerEnabled => 'Включен';

  @override
  String get drawerDisabled => 'Выключен';

  @override
  String get drawerHistory => 'История заказов';

  @override
  String get drawerSignOut => 'Выйти';

  @override
  String deliveryPackage(String description) {
    return 'Посылка: $description';
  }

  @override
  String deliveryRecipient(String name) {
    return 'Получатель: $name';
  }

  @override
  String deliveryPhone(String phone) {
    return 'Телефон: $phone';
  }

  @override
  String get deliveryCallRecipient => 'Позвонить получателю';

  @override
  String deliveryApartment(String apartment) {
    return 'Квартира: $apartment';
  }

  @override
  String get deliveryDialerFailed => 'Не удалось открыть приложение звонков.';

  @override
  String intercityKazakhstanTime(String time) {
    return '$time · Время Казахстана';
  }

  @override
  String intercityPassengers(int count) {
    return 'Пассажиров: $count';
  }

  @override
  String get intercityHasLuggage => 'Есть багаж';

  @override
  String intercityComment(String comment) {
    return 'Комментарий: $comment';
  }

  @override
  String intercityPrice(int price) {
    return 'Цена: $price ₸';
  }

  @override
  String get intercitySearchCityHint => 'Город или населённый пункт';

  @override
  String get intercityStreetHouseHint => 'Улица и дом';

  @override
  String get intercityChooseOnMap => 'Выбрать на карте';

  @override
  String get profileWrongPassword => 'Неверный пароль.';

  @override
  String get profileTooManyAttempts =>
      'Слишком много попыток. Попробуйте позже.';

  @override
  String get profileNetworkError =>
      'Нет соединения с сетью. Попробуйте ещё раз.';

  @override
  String get profileUserDisabled => 'Этот аккаунт отключён.';

  @override
  String get profileUserNotFound => 'Не удалось подтвердить текущий аккаунт.';

  @override
  String get profileRecentLoginRequired =>
      'Требуется повторный вход в аккаунт.';

  @override
  String get profileReauthFailed => 'Не удалось подтвердить пароль.';

  @override
  String get profileDeletionUnknown =>
      'Не удалось подтвердить результат удаления. Проверьте состояние аккаунта позже.';

  @override
  String get intercityOrderCar => 'Заказать машину';

  @override
  String get intercityOrderCarHint => 'Машина целиком до нужного адреса';

  @override
  String get intercityFindRide => 'Найти попутку';

  @override
  String get intercityFindRideHint => 'Забронировать место в поездке водителя';

  @override
  String get intercityMyBookings => 'Мои бронирования';

  @override
  String get intercityLookingForRide => 'Ищу попутку';

  @override
  String get intercityChooseCities =>
      'Выберите города отправления и назначения.';

  @override
  String get intercityDifferentCities =>
      'Города отправления и назначения должны отличаться.';

  @override
  String get intercityDatePast => 'Дата поездки не может быть в прошлом.';

  @override
  String get intercitySeatsRange => 'Выберите от 1 до 7 мест.';

  @override
  String get intercityFrom => 'Откуда';

  @override
  String get intercityTo => 'Куда';

  @override
  String get intercityTravelDate => 'Дата поездки';

  @override
  String get intercityFindTrips => 'Найти поездки';

  @override
  String get intercitySeatCount => 'Количество мест';

  @override
  String get intercityDecrease => 'Уменьшить';

  @override
  String get intercityIncrease => 'Увеличить';

  @override
  String intercitySeatSemantics(int count) {
    return 'Количество мест: $count';
  }

  @override
  String get intercityMatchingTrips => 'Подходящие поездки';

  @override
  String get intercityTripsLoadFailed => 'Не удалось загрузить поездки';

  @override
  String get intercityNoTrips => 'Подходящих поездок пока нет';

  @override
  String get intercityLeaveRequest => 'Оставить заявку';

  @override
  String intercityAvailableSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Свободно: $count мест',
      many: 'Свободно: $count мест',
      few: 'Свободно: $count места',
      one: 'Свободно: $count место',
    );
    return '$_temp0';
  }

  @override
  String intercityPerSeat(String price) {
    return '$price / место';
  }

  @override
  String get intercityDetails => 'Подробнее';

  @override
  String get datePreviousMonth => 'Предыдущий месяц';

  @override
  String get dateNextMonth => 'Следующий месяц';

  @override
  String get dateDone => 'Готово';

  @override
  String get historyNoAddress => 'Адрес не указан';

  @override
  String get historyDriverRole => 'Я — водитель';

  @override
  String get historyPassengerRole => 'Я — пассажир';

  @override
  String get historyTitle => 'История поездок';

  @override
  String get historyLoadFailed => 'Не удалось загрузить историю поездок.';

  @override
  String get historyEmpty => 'У вас пока нет завершённых поездок';

  @override
  String get historyCompleted => 'Завершён';

  @override
  String get historyCancelled => 'Отменён';

  @override
  String historyPrice(String price) {
    return '$price ₸';
  }

  @override
  String get driverMapActionFailed =>
      'Не удалось обновить заказ. Повторите попытку.';

  @override
  String get driverMapRerouteFailed => 'Не удалось перестроить маршрут';

  @override
  String get driverMapCustomer => 'заказчика';

  @override
  String get driverMapNextLoadFailed =>
      'Следующий заказ принят. Не удалось загрузить данные.';

  @override
  String get driverMapNextAccepted => 'Следующий заказ принят';

  @override
  String get driverMapNextUnavailable => 'Заказ уже недоступен';

  @override
  String get driverMapOwnPrice => 'Своя цена';

  @override
  String get driverMapPriceLabel => 'Цена, ₸';

  @override
  String get driverMapOfferSent => 'Предложение отправлено пассажиру';

  @override
  String get driverMapArrivedAction => 'Я на месте';

  @override
  String get driverMapPackageReceived => 'Посылка получена';

  @override
  String get driverMapStartTrip => 'Начать поездку';

  @override
  String get driverMapCompleteDelivery => 'Завершить доставку';

  @override
  String get driverMapCompleteTrip => 'Завершить поездку';

  @override
  String get driverMapDeliveryTitle => 'Выполнение доставки';

  @override
  String get driverMapIntercityTitle => 'Междугородняя поездка';

  @override
  String get driverMapCityTitle => 'Выполнение заказа';

  @override
  String driverMapCollectPackage(String address) {
    return 'Заберите посылку: $address';
  }

  @override
  String driverMapClientWaiting(String address) {
    return 'Клиент ожидает: $address';
  }

  @override
  String get orderOfferAcceptFailed =>
      'Не удалось принять предложение. Повторите попытку.';

  @override
  String get trackingStopped => 'Отслеживание геопозиции остановлено.';

  @override
  String get trackingSignIn => 'Войдите в аккаунт водителя.';

  @override
  String get trackingEnableServices => 'Включите службы геолокации.';

  @override
  String get trackingAllowLocation => 'Разрешите доступ к геолокации.';

  @override
  String get trackingAllowInSettings =>
      'Разрешите геолокацию в настройках приложения.';

  @override
  String get trackingPositionFailed =>
      'Не удалось получить или отправить текущую геопозицию.';

  @override
  String get driverChangeOffer => 'Изменить предложение';

  @override
  String driverPassengerPrice(int price) {
    return 'Цена пассажира: $price ₸';
  }

  @override
  String get driverYourPrice => 'Ваша цена, ₸';

  @override
  String get driverEnterWholeAmount => 'Введите целую сумму.';

  @override
  String get driverOfferAbovePrice =>
      'Предложение должно быть выше цены пассажира.';

  @override
  String get driverOfferTooHigh =>
      'Цена предложения не может превышать 1 000 000 ₸.';

  @override
  String driverOfferSent(int price) {
    return 'Предложение $price ₸ отправлено пассажиру.';
  }

  @override
  String get driverOfferFailed =>
      'Не удалось отправить предложение. Попробуйте ещё раз.';

  @override
  String get driverNotAuthenticated => 'Водитель не авторизован';

  @override
  String get driverOnline => 'На линии';

  @override
  String get driverActiveCheckFailed =>
      'Не удалось проверить текущий заказ. Проверка повторяется автоматически.';

  @override
  String get driverNoOrders => 'Пока нет доступных заказов';

  @override
  String get passenger => 'Пассажир';

  @override
  String distanceKilometers(String distance) {
    return '$distance км';
  }

  @override
  String pricePerKilometer(int price) {
    return '$price ₸/км';
  }

  @override
  String driverYouOffered(int price) {
    return 'Вы предложили $price ₸';
  }

  @override
  String get driverChangePrice => 'Изменить цену';

  @override
  String driverAcceptForPrice(int price) {
    return 'Принять за $price ₸';
  }

  @override
  String get driverOrdersForbidden =>
      'Нет доступа к заказам. Профиль водителя должен быть одобрен.';

  @override
  String get driverOrdersConfigFailed =>
      'Запрос заказов недоступен. Проверьте настройки сервиса.';

  @override
  String get driverOrdersTimeout =>
      'Сервер не ответил вовремя. Проверка заказов повторится автоматически.';

  @override
  String get driverOrdersLoadFailed =>
      'Не удалось обновить доступные заказы. Проверка повторится автоматически.';

  @override
  String get bookingCancelTitle => 'Отменить бронь?';

  @override
  String get bookingBack => 'Назад';

  @override
  String get bookingCancelExplanation =>
      'Забронированные места снова станут доступными.';

  @override
  String get bookingCancel => 'Отменить бронь';

  @override
  String get bookingCancelFailed =>
      'Не удалось отменить бронь. Попробуйте ещё раз.';

  @override
  String get bookingLoadFailed => 'Не удалось загрузить бронирования';

  @override
  String get bookingEmpty => 'У вас пока нет бронирований';

  @override
  String bookingSeatsAndPrice(int count, String price) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мест',
      many: '$count мест',
      few: '$count места',
      one: '$count место',
    );
    return '$_temp0 · $price';
  }

  @override
  String bookingPickup(String address) {
    return 'Точка посадки: $address';
  }

  @override
  String bookingComment(String comment) {
    return 'Комментарий водителю: $comment';
  }

  @override
  String bookingDriver(String name) {
    return 'Водитель: $name';
  }

  @override
  String bookingPhone(String phone) {
    return 'Телефон: $phone';
  }

  @override
  String get bookingUpcoming => 'Предстоящие';

  @override
  String get bookingCancelled => 'Отменённые';

  @override
  String get bookingCompleted => 'Завершённые';

  @override
  String get bookingOther => 'Другие';

  @override
  String get profileActiveOrder =>
      'Сначала завершите или отмените текущий заказ.';

  @override
  String get profileActiveDriverOrder =>
      'Сначала завершите активный заказ водителя.';

  @override
  String get profileActiveRide =>
      'Сначала завершите или отмените поездку «Попутки».';

  @override
  String get profileActiveBooking =>
      'Сначала завершите или отмените бронирование.';

  @override
  String get profileActiveRideRequest =>
      'Сначала отмените активный запрос «Попутки».';

  @override
  String get profileDeletionManualReview =>
      'Удаление требует проверки службой поддержки.';

  @override
  String get driverIntercityOrders => 'Заказы пассажиров';

  @override
  String get driverIntercityOrdersHint => 'Обычные междугородние заказы';

  @override
  String get driverIntercityMyRides => 'Мои поездки';

  @override
  String get driverIntercityMyRidesHint =>
      'Опубликованные попутки и бронирования';

  @override
  String get driverIntercityCreateRide => 'Создать поездку';

  @override
  String get driverIntercityCreateHint => 'Опубликовать места для попутчиков';

  @override
  String get intercityPickupPoint => 'Точка посадки';

  @override
  String get driverRidesEmpty => 'Вы ещё не публиковали поездки';

  @override
  String driverRideTotalSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Всего $count мест',
      many: 'Всего $count мест',
      few: 'Всего $count места',
      one: 'Всего $count место',
    );
    return '$_temp0';
  }

  @override
  String get driverRideScheduled => 'Запланирована';

  @override
  String get driverRideDeparted => 'В пути';

  @override
  String get driverRideCompleted => 'Завершена';

  @override
  String get driverRideCancelled => 'Отменена';

  @override
  String get driverRideUnknown => 'Статус неизвестен';

  @override
  String get driverRideGroupDeparted => 'В пути';

  @override
  String get publicDriverLoadFailed => 'Не удалось загрузить профиль водителя';

  @override
  String get publicDriverNoRatings => 'Нет оценок';

  @override
  String publicDriverRatingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count оценок',
      many: '$count оценок',
      few: '$count оценки',
      one: '$count оценка',
    );
    return '$_temp0';
  }

  @override
  String get publicDriverReviews => 'Отзывы';

  @override
  String get publicDriverNoReviews => 'Отзывов пока нет';

  @override
  String get ratingTitleDriver => 'Оцените водителя';

  @override
  String get ratingCourierObject => 'курьера';

  @override
  String get ratingTitlePassenger => 'Оцените пассажира';

  @override
  String ratingTitleName(String name) {
    return 'Оцените $name';
  }

  @override
  String ratingStarTooltip(int score) {
    return '$score из 5';
  }

  @override
  String get ratingReviewHint => 'Напишите отзыв (необязательно)';

  @override
  String get ratingCancel => 'Отмена';

  @override
  String get ratingSubmit => 'Отправить';

  @override
  String get ratingInvalidRequest => 'Ошибка в данных или параметрах запроса.';

  @override
  String get ratingForbidden => 'У вас недостаточно прав для оценки.';

  @override
  String get ratingOrderMissing => 'Заказ для оценивания не найден.';

  @override
  String get ratingAlreadySent => 'Оценка по этому заказу уже отправлена.';

  @override
  String get ratingNotCompleted => 'Можно оценивать только завершённый заказ.';

  @override
  String get ratingInvalidScore =>
      'Поставьте оценку от 1 до 5. Отзыв — не более 500 символов.';

  @override
  String get ratingFailed => 'Не удалось отправить оценку. Попробуйте ещё раз.';

  @override
  String get mapSelectedPoint => 'Выбранная точка';

  @override
  String get mapPickupMarker => 'Точка подачи';

  @override
  String get mapDestinationMarker => 'Точка назначения';

  @override
  String get mapUserMarker => 'Ваше местоположение';

  @override
  String get mapCourierMarker => 'Курьер на карте';

  @override
  String get mapVehicleMarker => 'Автомобиль на карте';

  @override
  String get intercityPickupPrompt => 'Откуда вас забрать?';

  @override
  String get requestSelectOriginFirst => 'Сначала выберите город отправления.';

  @override
  String get requestFutureDate =>
      'Заявку можно оставить только на будущую дату.';

  @override
  String get requestCommentTooLong =>
      'Комментарий не должен превышать 1000 символов.';

  @override
  String get requestSelectPickup => 'Выберите точку посадки.';

  @override
  String get requestSaved => 'Заявка сохранена';

  @override
  String get requestDuplicate => 'Такая активная заявка уже существует.';

  @override
  String get requestSaveFailed =>
      'Не удалось сохранить заявку. Попробуйте ещё раз.';

  @override
  String get requestCancelTitle => 'Отменить заявку?';

  @override
  String get requestCancelFailed =>
      'Не удалось отменить заявку. Попробуйте ещё раз.';

  @override
  String get requestNotifyHint => 'Сообщим, когда появится подходящая поездка.';

  @override
  String get requestCommentLabel => 'Комментарий водителю (необязательно)';

  @override
  String get requestCommentHint => 'Например, подъедьте к главному входу';

  @override
  String get requestMyRequests => 'Мои заявки';

  @override
  String get requestLoadFailed => 'Не удалось загрузить заявки';

  @override
  String get requestEmpty => 'Активных заявок пока нет';

  @override
  String requestDateSeats(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мест',
      many: '$count мест',
      few: '$count места',
      one: '$count место',
    );
    return '$date · $_temp0';
  }

  @override
  String get requestMatchedRides => 'Найдены поездки:';

  @override
  String requestMatchedRide(int number) {
    return 'Поездка $number';
  }

  @override
  String get requestCancel => 'Отменить заявку';

  @override
  String get requestActive => 'Активна';

  @override
  String get requestCancelled => 'Отменена';

  @override
  String get requestExpired => 'Истекла';

  @override
  String get recoveryCheckFailed =>
      'Не удалось проверить профиль. Проверьте интернет и повторите.';

  @override
  String get recoveryNameLimit => 'Введите имя длиной не более 80 символов.';

  @override
  String get recoveryTitle => 'Восстановление профиля';

  @override
  String get recoveryLegacyTitle => 'Профиль имеет старый формат';

  @override
  String get recoveryEnterName => 'Укажите имя';

  @override
  String get recoveryIncomplete => 'Не удалось завершить проверку';

  @override
  String get recoveryAdminBody =>
      'Защищённые поля нельзя безопасно восстановить с телефона. Для этого профиля требуется точечная административная миграция.';

  @override
  String get recoveryAdminFields => 'Требуют административного восстановления:';

  @override
  String get recoveryLegacyWarning =>
      'Старые isDriver, driverActiveUntil и данные автомобиля обнаружены, но не используются для выдачи водительских прав.';

  @override
  String get recoveryNameBody =>
      'Имя отсутствует в профиле и Firebase Auth. Введите своё имя — остальные защищённые поля останутся без изменений.';

  @override
  String get recoverySaveContinue => 'Сохранить и продолжить';

  @override
  String get recoveryCheckAgain => 'Проверить снова';

  @override
  String get recoverySignOut => 'Выйти из аккаунта';

  @override
  String get recoveryFieldUid => 'идентификатор аккаунта (uid)';

  @override
  String get recoveryFieldName => 'имя';

  @override
  String get recoveryFieldPhone => 'подтверждённый телефон';

  @override
  String get recoveryFieldRole => 'базовая роль passenger';

  @override
  String get recoveryFieldRating => 'начальный рейтинг 5.0';

  @override
  String get recoveryFieldCreatedAt => 'дата создания из Firebase Auth';

  @override
  String get driverRideUpdated => 'Поездка обновлена';

  @override
  String get driverRidePublished => 'Поездка опубликована';

  @override
  String get driverRideEditTitle => 'Редактировать поездку';

  @override
  String get driverRideCreateTitle => 'Создать поездку';

  @override
  String get driverRideProtected =>
      'Маршрут, время и количество мест нельзя изменить после бронирования.';

  @override
  String get driverRideRoute => 'Маршрут';

  @override
  String get driverRideDate => 'Дата';

  @override
  String get driverRideTime => 'Время';

  @override
  String get driverRidePricePerSeat => 'Цена за место';

  @override
  String get driverRidePriceNotice =>
      'Новая цена не изменит сумму уже созданных бронирований.';

  @override
  String get driverRideLuggageAllowed => 'Багаж разрешён';

  @override
  String get driverRideNoLuggage => 'Без багажа';

  @override
  String get driverRideComment => 'Комментарий';

  @override
  String get driverRidePublish => 'Опубликовать поездку';

  @override
  String get driverRideChooseCities =>
      'Выберите города отправления и назначения.';

  @override
  String get driverRideDifferentCities =>
      'Города отправления и назначения должны отличаться.';

  @override
  String get driverRideFutureTime => 'Выберите будущую дату и время.';

  @override
  String get driverRideSeatsRange => 'Можно предложить от 1 до 7 мест.';

  @override
  String get driverRideInvalidPrice => 'Укажите корректную цену за место.';

  @override
  String get driverRideCommentLong => 'Комментарий слишком длинный.';

  @override
  String get driverRideInvalidData => 'Проверьте данные поездки.';

  @override
  String get driverRideLogin => 'Войдите в аккаунт и повторите.';

  @override
  String get driverRideAccess => 'Доступ водителя не активен.';

  @override
  String get driverRideMissing => 'Поездка не найдена.';

  @override
  String get driverRideChanged => 'Поездка уже изменилась. Обновите данные.';

  @override
  String get driverRideSaveFailed => 'Не удалось сохранить поездку.';

  @override
  String get driverRideServerTimeout => 'Сервер не ответил. Повторите позже.';

  @override
  String get bookingPickupCityFailed => 'Не удалось определить город посадки.';

  @override
  String get bookingSelectPickup => 'Выберите точку посадки.';

  @override
  String get bookingCommentLimit =>
      'Комментарий не должен превышать 1000 символов.';

  @override
  String get bookingConfirmTitle => 'Подтвердить бронирование?';

  @override
  String get bookingBook => 'Забронировать';

  @override
  String get bookingBooked => 'Место забронировано';

  @override
  String get bookingSavedBody =>
      'Бронь сохранена в разделе «Мои бронирования».';

  @override
  String get bookingStay => 'Остаться';

  @override
  String get bookingRide => 'Поездка';

  @override
  String get bookingLoadRideFailed => 'Не удалось загрузить поездку';

  @override
  String bookingTotal(String price) {
    return 'Итого: $price';
  }

  @override
  String bookingBookSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мест',
      many: '$count мест',
      few: '$count места',
      one: '$count место',
    );
    return 'Забронировать $_temp0';
  }

  @override
  String bookingConfirmSummary(String seats, String price, String address) {
    return '$seats · $price\n$address';
  }

  @override
  String get bookingRideChanged =>
      'Поездка изменилась или свободных мест уже недостаточно.';

  @override
  String get bookingLogin => 'Войдите в аккаунт и повторите попытку.';

  @override
  String get bookingServerTimeout => 'Сервер не ответил. Повторите попытку.';

  @override
  String get bookingFailed =>
      'Не удалось забронировать место. Повторите попытку.';

  @override
  String get driverRideDetailsTitle => 'Детали поездки';

  @override
  String get driverRideStatusLabel => 'Статус';

  @override
  String get driverRideDeparture => 'Отправление';

  @override
  String get driverRideTotalSeatsLabel => 'Мест всего';

  @override
  String get driverRideAvailableSeatsLabel => 'Свободно мест';

  @override
  String get driverRideBookedSeatsLabel => 'Забронировано мест';

  @override
  String get driverRideLuggage => 'Багаж';

  @override
  String get driverRideYes => 'Разрешён';

  @override
  String get driverRideNo => 'Нет';

  @override
  String get driverRideVehicle => 'Автомобиль';

  @override
  String get driverRidePassengers => 'Пассажиры';

  @override
  String get driverRideNoBookings => 'Пока никто не забронировал место';

  @override
  String get driverRideCancelTrip => 'Отменить поездку';

  @override
  String get driverRideStartTrip => 'Начать поездку';

  @override
  String get driverRideFinishTrip => 'Завершить поездку';

  @override
  String get driverRideBookingConfirmed => 'Подтверждено';

  @override
  String get driverRideBookingCancelled => 'Отменено';

  @override
  String get driverRideBookingCompleted => 'Завершено';

  @override
  String get driverRideBookingUnknown => 'Статус неизвестен';

  @override
  String get driverRideCancelTitle => 'Отменить поездку?';

  @override
  String get driverRideDepartTitle => 'Начать поездку?';

  @override
  String get driverRideCompleteTitle => 'Завершить поездку?';

  @override
  String get driverRideCancelAction => 'Отменить';

  @override
  String get driverRideDepartAction => 'Начать';

  @override
  String get driverRideCompleteAction => 'Завершить';

  @override
  String get driverRideCancelBookingsWarning =>
      'Все бронирования пассажиров будут отменены.';

  @override
  String get driverRideCancelNoBookings =>
      'Поездка больше не будет доступна пассажирам.';

  @override
  String get driverRideDepartWarning =>
      'После отправления новые бронирования и отмена пассажиром будут недоступны.';

  @override
  String get driverRideCompleteWarning => 'Подтвердите завершение поездки.';

  @override
  String driverRideBookingSummary(int count, String price) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мест',
      many: '$count мест',
      few: '$count места',
      one: '$count место',
    );
    return '$_temp0 · $price';
  }

  @override
  String driverRidePassengerName(String name) {
    return 'Пассажир: $name';
  }

  @override
  String driverRidePickupComment(String comment) {
    return 'Комментарий пассажира: $comment';
  }

  @override
  String get driverRideShowMap => 'Показать на карте';

  @override
  String get navigationGpsRequired => 'Необходимо разрешение на доступ к GPS';

  @override
  String get navigationRecalculating => 'Перестраиваем маршрут...';

  @override
  String get navigationRecalculateFailed => 'Не удалось перестроить маршрут.';

  @override
  String get navigationTitle => 'Навигация заказа';

  @override
  String get navigationMapPlaceholder => 'Карта здесь отображается';

  @override
  String get timePickerChoose => 'Выберите время';

  @override
  String get timePickerHours => 'Часы';

  @override
  String get timePickerMinutes => 'Минуты';

  @override
  String get timePickerDone => 'Готово';

  @override
  String get nextOrderNearby => 'Следующий заказ рядом';

  @override
  String nextOrderDistance(int meters) {
    return 'Подача в $meters м';
  }

  @override
  String get nextOrderOwnPrice => 'Своя цена';

  @override
  String get nextOrderAccept => 'Принять';

  @override
  String get registerUnexpectedError =>
      'Не удалось зарегистрироваться. Попробуйте ещё раз.';

  @override
  String get driverOrderUpdateFailed =>
      'Не удалось обновить статус заказа. Попробуйте ещё раз.';

  @override
  String get driverOrderHeading => 'Едем к клиенту';

  @override
  String get driverOrderWaiting => 'Ожидание клиента';

  @override
  String get driverOrderInProgress => 'Поездка в процессе';

  @override
  String get driverOrderAtPickup => 'На месте';

  @override
  String get driverOrderStart => 'Начать поездку';

  @override
  String get driverOrderFinish => 'Завершить поездку';

  @override
  String get driverOrderCost => 'Стоимость:';

  @override
  String bookingSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мест',
      many: '$count мест',
      few: '$count места',
      one: '$count место',
    );
    return '$_temp0';
  }

  @override
  String get navContinueToPoint => 'Продолжайте к точке';

  @override
  String get navArrived => 'Вы прибыли';

  @override
  String get navDepart => 'Начните движение';

  @override
  String get navExitRoundabout => 'Съезжайте с кольца';

  @override
  String get navEnterRoundabout => 'Въезжайте на кольцо';

  @override
  String navRoundaboutExit(int exitNumber) {
    return 'На кольце сверните на $exitNumber-й съезд';
  }

  @override
  String get navUTurn => 'Развернитесь';

  @override
  String get navKeepLeft => 'Держитесь левее';

  @override
  String get navKeepRight => 'Держитесь правее';

  @override
  String get navContinue => 'Продолжайте движение';

  @override
  String get navMergeLeft => 'Влейтесь в поток слева';

  @override
  String get navMergeRight => 'Влейтесь в поток справа';

  @override
  String get navMerge => 'Влейтесь в поток';

  @override
  String get navOnRamp => 'Выезжайте на съезд';

  @override
  String get navOffRamp => 'Сверните на съезд';

  @override
  String get navStraight => 'Продолжайте прямо';

  @override
  String get navTurnSharpLeft => 'Резко поверните налево';

  @override
  String get navTurnSharpRight => 'Резко поверните направо';

  @override
  String get navTurnSlightLeft => 'Плавно поверните налево';

  @override
  String get navTurnSlightRight => 'Плавно поверните направо';

  @override
  String get navTurnLeft => 'Поверните налево';

  @override
  String get navTurnRight => 'Поверните направо';

  @override
  String navDistanceMeters(int value) {
    return 'Через $value м';
  }

  @override
  String navDistanceKilometers(String value) {
    return 'Через $value км';
  }

  @override
  String navMetersShort(int value) {
    return '$value м';
  }

  @override
  String navKilometersShort(String value) {
    return '$value км';
  }

  @override
  String navMinutesShort(int value) {
    return '$value мин';
  }

  @override
  String navHoursMinutesShort(int hours, int minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String navRemaining(String summary) {
    return 'Осталось: $summary';
  }

  @override
  String get mapAddAddress => 'Добавить адрес';

  @override
  String mapStopNumber(int number) {
    return 'Остановка $number';
  }

  @override
  String get mapFinalDestination => 'Конечная точка';

  @override
  String get mapRemoveStop => 'Удалить остановку';

  @override
  String get mapChooseAllStops => 'Выберите адрес для каждой остановки.';

  @override
  String get driverMapNextStop => 'Следующая остановка';

  @override
  String get intercityOpenChat => 'Открыть чат';

  @override
  String get intercityWhatsApp => 'Написать в WhatsApp';

  @override
  String get intercityWhatsAppUnavailable => 'Не удалось открыть WhatsApp.';

  @override
  String get intercityNavigationUnavailable =>
      'Для этого рейса не указаны координаты конечной точки.';

  @override
  String get intercityNavigationTitle => 'Навигация межгород';

  @override
  String get intercityNextPoint => 'Следующая точка';

  @override
  String get intercityFinishRide => 'Завершить поездку';

  @override
  String get pushIntercityTripCompleted => 'Междугородняя поездка завершена';

  @override
  String get pushIntercityChatMessage => 'Новое сообщение по поездке';

  @override
  String get intercityContinueActiveTrip => 'Продолжить поездку';

  @override
  String get intercityMarkPickupReached => 'Пассажир забран';

  @override
  String get intercityPickupReached => 'Пассажир уже забран';

  @override
  String get intercityActiveTripUnknown =>
      'Не удалось проверить активную поездку. Попробуйте ещё раз.';

  @override
  String get cityCancelTripTitle => 'Отменить поездку?';

  @override
  String get cityCancelTripWarning =>
      'Поездка уже началась. Отменяйте её только при необходимости.';

  @override
  String get cityCancelReasonLabel => 'Выберите причину отмены';

  @override
  String get cityCancelReasonRequired => 'Выберите причину отмены поездки.';

  @override
  String get cityCancelReasonPlansChanged => 'Изменились планы';

  @override
  String get cityCancelReasonCarProblem => 'Проблема с автомобилем';

  @override
  String get cityCancelReasonDriverProblem => 'Проблема с водителем';

  @override
  String get cityCancelReasonCarBreakdown => 'Поломка автомобиля';

  @override
  String get cityCancelReasonRoadIncident => 'ДТП / дорожная ситуация';

  @override
  String get cityCancelReasonPassengerRequested => 'Пассажир попросил отменить';

  @override
  String get cityCancelReasonPassengerProblem => 'Проблема с пассажиром';

  @override
  String get cityCancelReasonEmergency => 'Экстренная ситуация';

  @override
  String get cityCancelReasonOther => 'Другая причина';

  @override
  String get cityCancelReasonDetails => 'Опишите причину (необязательно)';

  @override
  String get cityCancelFinalConfirmation =>
      'Подтвердить отмену начавшейся поездки?';

  @override
  String get pushCityCancelledByPassenger => 'Заказ отменён пассажиром';

  @override
  String get pushCityCancelledByDriver => 'Водитель отменил поездку';

  @override
  String get deliveryRouteSection => 'Маршрут';

  @override
  String get deliveryParcelSection => 'Что доставляем';

  @override
  String get deliveryContactsSection => 'Контакты';

  @override
  String get deliverySenderSection => 'Отправитель';

  @override
  String get deliverySenderCurrentUser =>
      'Вы — пользователь, оформляющий заказ';

  @override
  String get deliveryRecipientSection => 'Получатель';

  @override
  String get deliveryAdditionalSection => 'Дополнительные детали';

  @override
  String get deliveryDetailsFilled => 'Заполнено';

  @override
  String get deliveryPriceSection => 'Стоимость доставки';

  @override
  String get driverWorkCity => 'Город работы';

  @override
  String get driverWorkCityChangeFailed =>
      'Не удалось сменить город работы. Завершите активную поездку или попробуйте позже.';

  @override
  String get citiesUnavailable =>
      'Не удалось загрузить список городов. Попробуйте ещё раз.';

  @override
  String get termsTitle => 'Условия использования';

  @override
  String termsBody(String version) {
    return 'Версия $version. Перед публикацией сообщений, отзывов и другого контента ознакомьтесь с условиями MEKEN. Не публикуйте оскорбления, угрозы, спам, незаконный или опасный контент. Вы можете пожаловаться на контент или заблокировать другого пользователя. Полный текст сохранён в документах MEKEN.';
  }

  @override
  String get termsConfirm => 'Я прочитал(а) и принимаю условия использования';

  @override
  String get termsAccept => 'Принять';

  @override
  String get termsAcceptFailed =>
      'Не удалось сохранить принятие условий. Попробуйте ещё раз.';

  @override
  String get reportUser => 'Пожаловаться';

  @override
  String get blockUser => 'Заблокировать пользователя';

  @override
  String get blockUserConfirm =>
      'Заблокировать этого пользователя для будущих поездок и общения после поездки?';

  @override
  String get reportSent => 'Жалоба отправлена';

  @override
  String get userBlocked => 'Пользователь заблокирован';

  @override
  String get reportReasonAbuse => 'Оскорбления';

  @override
  String get reportReasonHarassment => 'Преследование';

  @override
  String get reportReasonSpam => 'Спам';

  @override
  String get reportReasonUnsafe => 'Опасное поведение';

  @override
  String get reportReasonInappropriate => 'Недопустимый контент';

  @override
  String get reportReasonOther => 'Другая причина';

  @override
  String get aboutSupportTitle => 'О приложении и поддержка';

  @override
  String get legalTerms => 'Условия использования';

  @override
  String get legalTermsHint => 'Открыть актуальный полный текст';

  @override
  String get legalPrivacy => 'Политика конфиденциальности';

  @override
  String get legalPrivacyHint => 'Как MEKEN обрабатывает ваши данные';

  @override
  String get legalAccountDeletion => 'Удаление аккаунта';

  @override
  String get legalAccountDeletionHint =>
      'Инструкция и публичная страница удаления';

  @override
  String get legalSupport => 'Поддержка';

  @override
  String get legalSupportPending => 'Контакт будет опубликован до выпуска';

  @override
  String get legalVersion => 'Версия приложения';

  @override
  String get legalOpenFailed => 'Не удалось открыть ссылку';
}
