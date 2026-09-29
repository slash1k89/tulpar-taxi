import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kk.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('kk'),
    Locale('ru'),
  ];

  /// No description provided for @loginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Авторизация'**
  String get loginTitle;

  /// No description provided for @verificationTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение номера'**
  String get verificationTitle;

  /// No description provided for @profileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Как к вам обращаться?'**
  String get profileTitle;

  /// No description provided for @phoneHint.
  ///
  /// In ru, this message translates to:
  /// **'На ваш номер поступит короткий звонок.\nВведите последние 4 цифры номера звонящего.'**
  String get phoneHint;

  /// No description provided for @codeHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите последние 4 цифры номера входящего звонка'**
  String get codeHint;

  /// No description provided for @profileHint.
  ///
  /// In ru, this message translates to:
  /// **'Имя будет отображаться в вашем профиле.'**
  String get profileHint;

  /// No description provided for @requestCode.
  ///
  /// In ru, this message translates to:
  /// **'Получить код звонком'**
  String get requestCode;

  /// No description provided for @confirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get confirm;

  /// No description provided for @continueLabel.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get continueLabel;

  /// No description provided for @resendIn.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить ещё раз через {seconds} сек.'**
  String resendIn(int seconds);

  /// No description provided for @resend.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить ещё раз'**
  String get resend;

  /// No description provided for @phoneNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона'**
  String get phoneNumber;

  /// No description provided for @lastFourDigits.
  ///
  /// In ru, this message translates to:
  /// **'Последние 4 цифры'**
  String get lastFourDigits;

  /// No description provided for @nameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get nameLabel;

  /// No description provided for @invalidPhone.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректный номер телефона.'**
  String get invalidPhone;

  /// No description provided for @invalidCode.
  ///
  /// In ru, this message translates to:
  /// **'Введите последние 4 цифры номера звонящего.'**
  String get invalidCode;

  /// No description provided for @invalidName.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя длиной от 2 до 120 символов.'**
  String get invalidName;

  /// No description provided for @resendCooldown.
  ///
  /// In ru, this message translates to:
  /// **'Повторный звонок пока недоступен.'**
  String get resendCooldown;

  /// No description provided for @checkPhone.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте номер телефона.'**
  String get checkPhone;

  /// No description provided for @invalidVerification.
  ///
  /// In ru, this message translates to:
  /// **'Неверный или просроченный код.'**
  String get invalidVerification;

  /// No description provided for @loginFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить вход. Попробуйте ещё раз.'**
  String get loginFailed;

  /// No description provided for @serverTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не ответил. Попробуйте ещё раз.'**
  String get serverTimeout;

  /// No description provided for @chooseLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать язык'**
  String get chooseLanguage;

  /// No description provided for @languageSetting.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get languageSetting;

  /// No description provided for @registerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Регистрация'**
  String get registerTitle;

  /// No description provided for @createAccount.
  ///
  /// In ru, this message translates to:
  /// **'Создание аккаунта'**
  String get createAccount;

  /// No description provided for @registerButton.
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрироваться'**
  String get registerButton;

  /// No description provided for @authSignIn.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get authSignIn;

  /// No description provided for @authForgotPassword.
  ///
  /// In ru, this message translates to:
  /// **'Забыли пароль?'**
  String get authForgotPassword;

  /// No description provided for @authResetPasswordTitle.
  ///
  /// In ru, this message translates to:
  /// **'Восстановление пароля'**
  String get authResetPasswordTitle;

  /// No description provided for @authCreatePasswordTitle.
  ///
  /// In ru, this message translates to:
  /// **'Создайте пароль'**
  String get authCreatePasswordTitle;

  /// No description provided for @authVerificationPhoneHint.
  ///
  /// In ru, this message translates to:
  /// **'Укажите номер для подтверждения звонком.'**
  String get authVerificationPhoneHint;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In ru, this message translates to:
  /// **'Пароль должен содержать не менее 8 символов.'**
  String get authPasswordTooShort;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In ru, this message translates to:
  /// **'Неверный номер телефона или пароль.'**
  String get authInvalidCredentials;

  /// No description provided for @authPasswordAlreadySet.
  ///
  /// In ru, this message translates to:
  /// **'Пароль уже установлен. Воспользуйтесь восстановлением.'**
  String get authPasswordAlreadySet;

  /// No description provided for @authVerificationRequired.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердите номер ещё раз.'**
  String get authVerificationRequired;

  /// No description provided for @authBackToLogin.
  ///
  /// In ru, this message translates to:
  /// **'Назад ко входу'**
  String get authBackToLogin;

  /// No description provided for @passwordLabel.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get passwordLabel;

  /// No description provided for @confirmPassword.
  ///
  /// In ru, this message translates to:
  /// **'Повторите пароль'**
  String get confirmPassword;

  /// No description provided for @enterName.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя'**
  String get enterName;

  /// No description provided for @nameTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Имя слишком длинное'**
  String get nameTooLong;

  /// No description provided for @enterPhone.
  ///
  /// In ru, this message translates to:
  /// **'Введите номер телефона'**
  String get enterPhone;

  /// No description provided for @enterFullPhone.
  ///
  /// In ru, this message translates to:
  /// **'Введите номер полностью'**
  String get enterFullPhone;

  /// No description provided for @enterPassword.
  ///
  /// In ru, this message translates to:
  /// **'Введите пароль'**
  String get enterPassword;

  /// No description provided for @shortPassword.
  ///
  /// In ru, this message translates to:
  /// **'Пароль должен содержать минимум 6 символов'**
  String get shortPassword;

  /// No description provided for @passwordMismatch.
  ///
  /// In ru, this message translates to:
  /// **'Пароли не совпадают'**
  String get passwordMismatch;

  /// No description provided for @registrationSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь зарегистрирован: {phone}'**
  String registrationSuccess(String phone);

  /// No description provided for @pushOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get pushOpen;

  /// No description provided for @pushDriverApproachingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Водитель скоро будет на месте'**
  String get pushDriverApproachingTitle;

  /// No description provided for @pushDriverApproachingBody.
  ///
  /// In ru, this message translates to:
  /// **'Пожалуйста, выходите к месту подачи — водитель уже подъезжает.'**
  String get pushDriverApproachingBody;

  /// No description provided for @pushNewMessage.
  ///
  /// In ru, this message translates to:
  /// **'Новое сообщение в чате'**
  String get pushNewMessage;

  /// No description provided for @pushOrderAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Водитель едет к вам'**
  String get pushOrderAccepted;

  /// No description provided for @pushDeliveryAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Курьер едет за посылкой'**
  String get pushDeliveryAccepted;

  /// No description provided for @pushDriverArrived.
  ///
  /// In ru, this message translates to:
  /// **'Водитель на месте и ожидает вас!'**
  String get pushDriverArrived;

  /// No description provided for @pushDeliveryArrived.
  ///
  /// In ru, this message translates to:
  /// **'Курьер прибыл за посылкой'**
  String get pushDeliveryArrived;

  /// No description provided for @pushTripStarted.
  ///
  /// In ru, this message translates to:
  /// **'Поездка началась'**
  String get pushTripStarted;

  /// No description provided for @pushDeliveryStarted.
  ///
  /// In ru, this message translates to:
  /// **'Посылка в пути'**
  String get pushDeliveryStarted;

  /// No description provided for @pushTripCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Поездка завершена!'**
  String get pushTripCompleted;

  /// No description provided for @pushDeliveryCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Доставка завершена'**
  String get pushDeliveryCompleted;

  /// No description provided for @pushOrderCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Заказ отменён'**
  String get pushOrderCancelled;

  /// No description provided for @pushNewDriverOrder.
  ///
  /// In ru, this message translates to:
  /// **'Новый заказ'**
  String get pushNewDriverOrder;

  /// No description provided for @pushDriverHeading.
  ///
  /// In ru, this message translates to:
  /// **'Водитель направляется к месту подачи.'**
  String get pushDriverHeading;

  /// No description provided for @pushIntercityMatch.
  ///
  /// In ru, this message translates to:
  /// **'Появилась подходящая попутка'**
  String get pushIntercityMatch;

  /// No description provided for @pushIntercityCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Водитель отменил попутку'**
  String get pushIntercityCancelled;

  /// No description provided for @pushIntercityDeparted.
  ///
  /// In ru, this message translates to:
  /// **'Попутка отправилась'**
  String get pushIntercityDeparted;

  /// No description provided for @pushIntercityBooked.
  ///
  /// In ru, this message translates to:
  /// **'Новое бронирование попутки'**
  String get pushIntercityBooked;

  /// No description provided for @pushIntercityBookingCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Бронирование попутки отменено'**
  String get pushIntercityBookingCancelled;

  /// No description provided for @serviceCity.
  ///
  /// In ru, this message translates to:
  /// **'Такси'**
  String get serviceCity;

  /// No description provided for @serviceDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Доставка'**
  String get serviceDelivery;

  /// No description provided for @serviceIntercity.
  ///
  /// In ru, this message translates to:
  /// **'Межгород'**
  String get serviceIntercity;

  /// No description provided for @driverCityOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заказы такси'**
  String get driverCityOrders;

  /// No description provided for @driverDeliveryOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заказы доставки'**
  String get driverDeliveryOrders;

  /// No description provided for @driverNewOrder.
  ///
  /// In ru, this message translates to:
  /// **'Новый заказ — {service}'**
  String driverNewOrder(String service);

  /// No description provided for @statusSearchingDriver.
  ///
  /// In ru, this message translates to:
  /// **'Поиск свободного водителя...'**
  String get statusSearchingDriver;

  /// No description provided for @statusSearchingCourier.
  ///
  /// In ru, this message translates to:
  /// **'Поиск свободного курьера...'**
  String get statusSearchingCourier;

  /// No description provided for @statusSearchingIntercity.
  ///
  /// In ru, this message translates to:
  /// **'Поиск водителя для межгорода...'**
  String get statusSearchingIntercity;

  /// No description provided for @statusCourierComing.
  ///
  /// In ru, this message translates to:
  /// **'Курьер едет за посылкой'**
  String get statusCourierComing;

  /// No description provided for @statusDriverComing.
  ///
  /// In ru, this message translates to:
  /// **'Водитель едет к вам'**
  String get statusDriverComing;

  /// No description provided for @statusCourierArrived.
  ///
  /// In ru, this message translates to:
  /// **'Курьер прибыл за посылкой'**
  String get statusCourierArrived;

  /// No description provided for @statusDriverArrived.
  ///
  /// In ru, this message translates to:
  /// **'Водитель на месте и ожидает вас!'**
  String get statusDriverArrived;

  /// No description provided for @statusIntercityDriverArrived.
  ///
  /// In ru, this message translates to:
  /// **'Водитель прибыл'**
  String get statusIntercityDriverArrived;

  /// No description provided for @statusHandPackage.
  ///
  /// In ru, this message translates to:
  /// **'Передайте посылку курьеру'**
  String get statusHandPackage;

  /// No description provided for @statusGoToCar.
  ///
  /// In ru, this message translates to:
  /// **'Пожалуйста, выходите к автомобилю'**
  String get statusGoToCar;

  /// No description provided for @statusPackageOnWay.
  ///
  /// In ru, this message translates to:
  /// **'Посылка в пути'**
  String get statusPackageOnWay;

  /// No description provided for @statusTripInProgress.
  ///
  /// In ru, this message translates to:
  /// **'Поездка в процессе'**
  String get statusTripInProgress;

  /// No description provided for @statusTripStarted.
  ///
  /// In ru, this message translates to:
  /// **'Поездка началась'**
  String get statusTripStarted;

  /// No description provided for @statusDeliveryCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Доставка завершена'**
  String get statusDeliveryCompleted;

  /// No description provided for @statusTripCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Поездка завершена!'**
  String get statusTripCompleted;

  /// No description provided for @statusIntercityCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Междугородняя поездка завершена'**
  String get statusIntercityCompleted;

  /// No description provided for @statusDriverFinishingPrevious.
  ///
  /// In ru, this message translates to:
  /// **'Водитель завершает предыдущую поездку'**
  String get statusDriverFinishingPrevious;

  /// No description provided for @cancelOrderTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отмена заказа'**
  String get cancelOrderTitle;

  /// No description provided for @confirmCancelOrder.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите отменить заказ?'**
  String get confirmCancelOrder;

  /// No description provided for @no.
  ///
  /// In ru, this message translates to:
  /// **'Нет'**
  String get no;

  /// No description provided for @yesCancel.
  ///
  /// In ru, this message translates to:
  /// **'Да, отменить'**
  String get yesCancel;

  /// No description provided for @offerAccepted.
  ///
  /// In ru, this message translates to:
  /// **'{driver}: предложение {price} ₸ принято.'**
  String offerAccepted(String driver, String price);

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @cancelOrderFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отменить заказ. Проверьте соединение и повторите попытку.'**
  String get cancelOrderFailed;

  /// No description provided for @yourOrder.
  ///
  /// In ru, this message translates to:
  /// **'Ваш заказ'**
  String get yourOrder;

  /// No description provided for @orderCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Заказ отменён'**
  String get orderCancelled;

  /// No description provided for @orderLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки данных заказа'**
  String get orderLoadFailed;

  /// No description provided for @invalidOrderCoordinates.
  ///
  /// In ru, this message translates to:
  /// **'Некорректные координаты заказа'**
  String get invalidOrderCoordinates;

  /// No description provided for @cancelling.
  ///
  /// In ru, this message translates to:
  /// **'Отмена...'**
  String get cancelling;

  /// No description provided for @cancelSearch.
  ///
  /// In ru, this message translates to:
  /// **'Отменить поиск'**
  String get cancelSearch;

  /// No description provided for @queuedOrderHint.
  ///
  /// In ru, this message translates to:
  /// **'После завершения водитель сразу направится к вам.'**
  String get queuedOrderHint;

  /// No description provided for @cancelOrder.
  ///
  /// In ru, this message translates to:
  /// **'Отменить заказ'**
  String get cancelOrder;

  /// No description provided for @recipientAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес получателя: {address}'**
  String recipientAddress(String address);

  /// No description provided for @directionAddress.
  ///
  /// In ru, this message translates to:
  /// **'Направление: {address}'**
  String directionAddress(String address);

  /// No description provided for @addressUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Адрес не указан'**
  String get addressUnknown;

  /// No description provided for @orderStatusUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Статус заказа: {status}'**
  String orderStatusUnknown(String status);

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get cancel;

  /// No description provided for @courier.
  ///
  /// In ru, this message translates to:
  /// **'Курьер'**
  String get courier;

  /// No description provided for @driver.
  ///
  /// In ru, this message translates to:
  /// **'Водитель'**
  String get driver;

  /// No description provided for @car.
  ///
  /// In ru, this message translates to:
  /// **'Автомобиль'**
  String get car;

  /// No description provided for @fromAddress.
  ///
  /// In ru, this message translates to:
  /// **'Откуда: {address}'**
  String fromAddress(String address);

  /// No description provided for @toAddress.
  ///
  /// In ru, this message translates to:
  /// **'Куда: {address}'**
  String toAddress(String address);

  /// No description provided for @priceTenge.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость: {price} ₸'**
  String priceTenge(String price);

  /// No description provided for @carLoading.
  ///
  /// In ru, this message translates to:
  /// **'Данные машины загружаются...'**
  String get carLoading;

  /// No description provided for @driverProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль водителя'**
  String get driverProfile;

  /// No description provided for @chat.
  ///
  /// In ru, this message translates to:
  /// **'Чат'**
  String get chat;

  /// No description provided for @taxiAndDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Такси и доставка'**
  String get taxiAndDelivery;

  /// No description provided for @chatInvalidLength.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение должно содержать от 1 до 2000 символов.'**
  String get chatInvalidLength;

  /// No description provided for @chatInvalidRequest.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка в данных или параметрах запроса.'**
  String get chatInvalidRequest;

  /// No description provided for @chatForbidden.
  ///
  /// In ru, this message translates to:
  /// **'У вас нет доступа к этому заказу.'**
  String get chatForbidden;

  /// No description provided for @chatOrderNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Заказ не найден.'**
  String get chatOrderNotFound;

  /// No description provided for @chatSendFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить сообщение.'**
  String get chatSendFailed;

  /// No description provided for @chatRateLimited.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много сообщений. Повторите через {seconds} сек.'**
  String chatRateLimited(int seconds);

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @chatEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет сообщений. Напишите первым!'**
  String get chatEmpty;

  /// No description provided for @chatMessageHint.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение...'**
  String get chatMessageHint;

  /// No description provided for @mapDeliveryPriceRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите цену доставки.'**
  String get mapDeliveryPriceRequired;

  /// No description provided for @mapTripPriceRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите цену поездки.'**
  String get mapTripPriceRequired;

  /// No description provided for @mapLocationSlow.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось быстро определить местоположение. Выберите адрес вручную.'**
  String get mapLocationSlow;

  /// No description provided for @mapOutsideCity.
  ///
  /// In ru, this message translates to:
  /// **'Ваше местоположение вне города {city}.'**
  String mapOutsideCity(String city);

  /// No description provided for @mapChoosePointInCity.
  ///
  /// In ru, this message translates to:
  /// **'Выберите точку в городе {city}.'**
  String mapChoosePointInCity(String city);

  /// No description provided for @mapResolvingAddress.
  ///
  /// In ru, this message translates to:
  /// **'Определение адреса...'**
  String get mapResolvingAddress;

  /// No description provided for @mapChoosePointInKazakhstan.
  ///
  /// In ru, this message translates to:
  /// **'Выберите точку на территории Казахстана.'**
  String get mapChoosePointInKazakhstan;

  /// No description provided for @mapPickupCity.
  ///
  /// In ru, this message translates to:
  /// **'Город отправления'**
  String get mapPickupCity;

  /// No description provided for @mapDestinationCity.
  ///
  /// In ru, this message translates to:
  /// **'Город назначения'**
  String get mapDestinationCity;

  /// No description provided for @mapChooseCity.
  ///
  /// In ru, this message translates to:
  /// **'Выберите город'**
  String get mapChooseCity;

  /// No description provided for @mapRouteFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось построить маршрут. Попробуйте ещё раз.'**
  String get mapRouteFailed;

  /// No description provided for @mapChooseFutureTime.
  ///
  /// In ru, this message translates to:
  /// **'Выберите будущее время.'**
  String get mapChooseFutureTime;

  /// No description provided for @mapChooseBothCities.
  ///
  /// In ru, this message translates to:
  /// **'Сначала выберите города отправления и назначения.'**
  String get mapChooseBothCities;

  /// No description provided for @mapChooseRoutePoints.
  ///
  /// In ru, this message translates to:
  /// **'Укажите точки A и B на карте или выберите их из списка.'**
  String get mapChooseRoutePoints;

  /// No description provided for @mapPointA.
  ///
  /// In ru, this message translates to:
  /// **'Точка A'**
  String get mapPointA;

  /// No description provided for @mapPointB.
  ///
  /// In ru, this message translates to:
  /// **'Точка B'**
  String get mapPointB;

  /// No description provided for @mapServerTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Нет ответа от сервера. Попробуйте ещё раз.'**
  String get mapServerTimeout;

  /// No description provided for @mapStaleOrder.
  ///
  /// In ru, this message translates to:
  /// **'Найдена устаревшая привязка заказа. Она не удалена автоматически. Обратитесь к администратору для проверки.'**
  String get mapStaleOrder;

  /// No description provided for @mapServiceInCity.
  ///
  /// In ru, this message translates to:
  /// **'{service} — {city}'**
  String mapServiceInCity(String service, String city);

  /// No description provided for @mapExactPickupAddress.
  ///
  /// In ru, this message translates to:
  /// **'Точный адрес отправления'**
  String get mapExactPickupAddress;

  /// No description provided for @mapChooseAddress.
  ///
  /// In ru, this message translates to:
  /// **'Выберите адрес'**
  String get mapChooseAddress;

  /// No description provided for @mapExactDeliveryAddress.
  ///
  /// In ru, this message translates to:
  /// **'Точный адрес доставки'**
  String get mapExactDeliveryAddress;

  /// No description provided for @mapExactDestinationAddress.
  ///
  /// In ru, this message translates to:
  /// **'Точный адрес назначения'**
  String get mapExactDestinationAddress;

  /// No description provided for @mapRecipientApartment.
  ///
  /// In ru, this message translates to:
  /// **'Квартира получателя (необязательно)'**
  String get mapRecipientApartment;

  /// No description provided for @mapPackageDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание посылки'**
  String get mapPackageDescription;

  /// No description provided for @mapPackageExample.
  ///
  /// In ru, this message translates to:
  /// **'Например: документы'**
  String get mapPackageExample;

  /// No description provided for @mapRecipientName.
  ///
  /// In ru, this message translates to:
  /// **'Имя получателя'**
  String get mapRecipientName;

  /// No description provided for @mapRecipientPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон получателя'**
  String get mapRecipientPhone;

  /// No description provided for @mapPassengerCount.
  ///
  /// In ru, this message translates to:
  /// **'Количество пассажиров'**
  String get mapPassengerCount;

  /// No description provided for @mapHasLuggage.
  ///
  /// In ru, this message translates to:
  /// **'Есть багаж'**
  String get mapHasLuggage;

  /// No description provided for @mapOptionalComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий (необязательно)'**
  String get mapOptionalComment;

  /// No description provided for @mapYourPrice.
  ///
  /// In ru, this message translates to:
  /// **'Ваша цена (₸)'**
  String get mapYourPrice;

  /// No description provided for @mapRequestDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Заказать доставку'**
  String get mapRequestDelivery;

  /// No description provided for @mapRequestIntercity.
  ///
  /// In ru, this message translates to:
  /// **'Заказать межгород'**
  String get mapRequestIntercity;

  /// No description provided for @mapRequestTaxi.
  ///
  /// In ru, this message translates to:
  /// **'Заказать такси'**
  String get mapRequestTaxi;

  /// No description provided for @orderErrorLogin.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в аккаунт и повторите попытку.'**
  String get orderErrorLogin;

  /// No description provided for @orderErrorActive.
  ///
  /// In ru, this message translates to:
  /// **'У вас уже есть активный заказ.'**
  String get orderErrorActive;

  /// No description provided for @orderErrorInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте адреса, цену и точки маршрута.'**
  String get orderErrorInvalid;

  /// No description provided for @orderErrorDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Заполните описание посылки, имя и телефон получателя.'**
  String get orderErrorDelivery;

  /// No description provided for @orderErrorIntercity.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте время и данные междугородней поездки.'**
  String get orderErrorIntercity;

  /// No description provided for @orderErrorPermission.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к созданию заказа.'**
  String get orderErrorPermission;

  /// No description provided for @orderErrorUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервером. Попробуйте ещё раз.'**
  String get orderErrorUnavailable;

  /// No description provided for @orderErrorUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось создать заказ. Попробуйте ещё раз.'**
  String get orderErrorUnknown;

  /// No description provided for @driverAcceptDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Доставка принята! Направляйтесь за посылкой.'**
  String get driverAcceptDelivery;

  /// No description provided for @driverAcceptIntercity.
  ///
  /// In ru, this message translates to:
  /// **'Междугородняя поездка принята! Направляйтесь к пассажиру.'**
  String get driverAcceptIntercity;

  /// No description provided for @driverAcceptCity.
  ///
  /// In ru, this message translates to:
  /// **'Заказ принят! Направляйтесь к клиенту.'**
  String get driverAcceptCity;

  /// No description provided for @driverAcceptFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось принять заказ. Попробуйте ещё раз.'**
  String get driverAcceptFailed;

  /// No description provided for @driverProposePrice.
  ///
  /// In ru, this message translates to:
  /// **'Предложить цену'**
  String get driverProposePrice;

  /// No description provided for @driverSendOffer.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get driverSendOffer;

  /// No description provided for @pickerResolvingAddress.
  ///
  /// In ru, this message translates to:
  /// **'Определение адреса...'**
  String get pickerResolvingAddress;

  /// No description provided for @pickerAddressUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось определить адрес. Координаты сохранены.'**
  String get pickerAddressUnavailable;

  /// No description provided for @pickerAddressTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Сервис адресов не отвечает. Координаты сохранены.'**
  String get pickerAddressTimeout;

  /// No description provided for @pickerCoordinate.
  ///
  /// In ru, this message translates to:
  /// **'Точка на карте ({latitude}, {longitude})'**
  String pickerCoordinate(String latitude, String longitude);

  /// No description provided for @pickerChooseInCity.
  ///
  /// In ru, this message translates to:
  /// **'Выберите точку в городе {city}.'**
  String pickerChooseInCity(String city);

  /// No description provided for @pickerCityCheckFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось проверить город. Проверьте сеть и повторите.'**
  String get pickerCityCheckFailed;

  /// No description provided for @pickerPointCheckFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось проверить точку. Попробуйте ещё раз.'**
  String get pickerPointCheckFailed;

  /// No description provided for @pickerEnableLocation.
  ///
  /// In ru, this message translates to:
  /// **'Включите геолокацию на телефоне.'**
  String get pickerEnableLocation;

  /// No description provided for @pickerLocationDenied.
  ///
  /// In ru, this message translates to:
  /// **'Доступ к геолокации не разрешён.'**
  String get pickerLocationDenied;

  /// No description provided for @pickerLocationSettings.
  ///
  /// In ru, this message translates to:
  /// **'Разрешите геолокацию в настройках приложения.'**
  String get pickerLocationSettings;

  /// No description provided for @pickerLocationSlow.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось быстро определить местоположение. Выберите точку вручную.'**
  String get pickerLocationSlow;

  /// No description provided for @pickerLocationFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось определить местоположение. Выберите точку вручную.'**
  String get pickerLocationFailed;

  /// No description provided for @pickerNoLocation.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить местоположение. Выберите точку вручную.'**
  String get pickerNoLocation;

  /// No description provided for @pickerCityCheckManual.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось проверить город. Выберите точку вручную или повторите.'**
  String get pickerCityCheckManual;

  /// No description provided for @pickerPickupTitle.
  ///
  /// In ru, this message translates to:
  /// **'Точка отправления'**
  String get pickerPickupTitle;

  /// No description provided for @pickerDestinationTitle.
  ///
  /// In ru, this message translates to:
  /// **'Точка назначения'**
  String get pickerDestinationTitle;

  /// No description provided for @pickerMyLocation.
  ///
  /// In ru, this message translates to:
  /// **'Моё местоположение'**
  String get pickerMyLocation;

  /// No description provided for @pickerChecking.
  ///
  /// In ru, this message translates to:
  /// **'Проверка...'**
  String get pickerChecking;

  /// No description provided for @pickerChoosePoint.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать эту точку'**
  String get pickerChoosePoint;

  /// No description provided for @profileNotAuthenticated.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь не авторизован'**
  String get profileNotAuthenticated;

  /// No description provided for @profileLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить профиль'**
  String get profileLoadFailed;

  /// No description provided for @profileSaved.
  ///
  /// In ru, this message translates to:
  /// **'Профиль сохранён'**
  String get profileSaved;

  /// No description provided for @profileLegacyError.
  ///
  /// In ru, this message translates to:
  /// **'Профиль имеет старый формат. Если после заполнения имени ошибка повторится, проверьте uid, телефон, роль и дату создания в Firebase.'**
  String get profileLegacyError;

  /// No description provided for @profileSaveCodeError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить профиль: {code}.'**
  String profileSaveCodeError(String code);

  /// No description provided for @profileSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить профиль.'**
  String get profileSaveFailed;

  /// No description provided for @profileDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить аккаунт?'**
  String get profileDeleteTitle;

  /// No description provided for @profileDeleteFinalTitle.
  ///
  /// In ru, this message translates to:
  /// **'Точно удалить аккаунт?'**
  String get profileDeleteFinalTitle;

  /// No description provided for @profileDeleteWarning.
  ///
  /// In ru, this message translates to:
  /// **'Это действие необратимо. Активные заказы и поездки необходимо сначала завершить или отменить.'**
  String get profileDeleteWarning;

  /// No description provided for @profileDeleteFinalWarning.
  ///
  /// In ru, this message translates to:
  /// **'После продолжения восстановить аккаунт и личные данные будет невозможно.'**
  String get profileDeleteFinalWarning;

  /// No description provided for @profileYesDelete.
  ///
  /// In ru, this message translates to:
  /// **'Да, удалить'**
  String get profileYesDelete;

  /// No description provided for @profileDeleteCallRequired.
  ///
  /// In ru, this message translates to:
  /// **'Для удаления аккаунта потребуется повторное подтверждение звонком.'**
  String get profileDeleteCallRequired;

  /// No description provided for @profileDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт удалён.'**
  String get profileDeleted;

  /// No description provided for @profileDeletionPending.
  ///
  /// In ru, this message translates to:
  /// **'Запрос на удаление принят. Завершение удаления может занять некоторое время.'**
  String get profileDeletionPending;

  /// No description provided for @profileDeleteFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить аккаунт.'**
  String get profileDeleteFailed;

  /// No description provided for @profileSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль и настройки'**
  String get profileSettingsTitle;

  /// No description provided for @profileName.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get profileName;

  /// No description provided for @profileEnterName.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя'**
  String get profileEnterName;

  /// No description provided for @profileNameTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Имя слишком длинное'**
  String get profileNameTooLong;

  /// No description provided for @profilePhone.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона'**
  String get profilePhone;

  /// No description provided for @profilePhoneReadonly.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона нельзя изменить'**
  String get profilePhoneReadonly;

  /// No description provided for @profileCar.
  ///
  /// In ru, this message translates to:
  /// **'Марка и модель авто'**
  String get profileCar;

  /// No description provided for @profileTheme.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get profileTheme;

  /// No description provided for @profileThemeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get profileThemeSystem;

  /// No description provided for @profileThemeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get profileThemeLight;

  /// No description provided for @profileThemeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get profileThemeDark;

  /// No description provided for @profileVoice.
  ///
  /// In ru, this message translates to:
  /// **'Голосовые подсказки'**
  String get profileVoice;

  /// No description provided for @profileVoiceHint.
  ///
  /// In ru, this message translates to:
  /// **'Озвучивать манёвры во время навигации'**
  String get profileVoiceHint;

  /// No description provided for @profileSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить данные'**
  String get profileSave;

  /// No description provided for @profilePasswordTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердите пароль'**
  String get profilePasswordTitle;

  /// No description provided for @profileCurrentPassword.
  ///
  /// In ru, this message translates to:
  /// **'Текущий пароль'**
  String get profileCurrentPassword;

  /// No description provided for @profileEnterPassword.
  ///
  /// In ru, this message translates to:
  /// **'Введите пароль'**
  String get profileEnterPassword;

  /// No description provided for @unreadMessages.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{0 сообщений} one{{count} сообщение} few{{count} сообщения} many{{count} сообщений} other{{count} сообщений}}'**
  String unreadMessages(int count);

  /// No description provided for @agreementSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить согласие. Попробуйте ещё раз.'**
  String get agreementSaveFailed;

  /// No description provided for @agreementRulesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Правила работы водителя'**
  String get agreementRulesTitle;

  /// No description provided for @agreementVersion.
  ///
  /// In ru, this message translates to:
  /// **'Соглашение версии {version}'**
  String agreementVersion(String version);

  /// No description provided for @agreementBody.
  ///
  /// In ru, this message translates to:
  /// **'Переходя в режим водителя, я подтверждаю, что:\n\n• имею право управлять автомобилем и использую технически исправный автомобиль;\n\n• соблюдаю правила дорожного движения и требования безопасности;\n\n• поддерживаю автомобиль в чистоте и вежливо общаюсь с пассажирами;\n\n• не выхожу на линию в состоянии, которое мешает безопасному управлению;\n\n• указываю достоверные сведения об автомобиле и не передаю аккаунт другим лицам;\n\n• использую данные пассажира только для выполнения заказа.'**
  String get agreementBody;

  /// No description provided for @agreementConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Я прочитал(а) правила и принимаю соглашение'**
  String get agreementConfirm;

  /// No description provided for @agreementAcceptContinue.
  ///
  /// In ru, this message translates to:
  /// **'Принять и продолжить'**
  String get agreementAcceptContinue;

  /// No description provided for @onboardingLoginRequired.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в аккаунт, чтобы включить режим водителя.'**
  String get onboardingLoginRequired;

  /// No description provided for @onboardingServerTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не ответил. Проверьте интернет и повторите попытку.'**
  String get onboardingServerTimeout;

  /// No description provided for @onboardingLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить профиль водителя.'**
  String get onboardingLoadFailed;

  /// No description provided for @onboardingActivated.
  ///
  /// In ru, this message translates to:
  /// **'Профиль водителя активирован'**
  String get onboardingActivated;

  /// No description provided for @onboardingRetryTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не ответил. Попробуйте ещё раз.'**
  String get onboardingRetryTimeout;

  /// No description provided for @onboardingSubmitFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить заявку водителя.'**
  String get onboardingSubmitFailed;

  /// No description provided for @onboardingPermissionDenied.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно прав для изменения водительского профиля.'**
  String get onboardingPermissionDenied;

  /// No description provided for @onboardingUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Сервис временно недоступен. Проверьте интернет.'**
  String get onboardingUnavailable;

  /// No description provided for @onboardingFirebaseError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка Firebase: {code}. Попробуйте ещё раз.'**
  String onboardingFirebaseError(String code);

  /// No description provided for @onboardingPendingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заявка водителя отправлена на проверку.'**
  String get onboardingPendingTitle;

  /// No description provided for @onboardingPendingBody.
  ///
  /// In ru, this message translates to:
  /// **'После одобрения режим водителя станет доступен автоматически. Соглашение и данные автомобиля повторно заполнять не нужно.'**
  String get onboardingPendingBody;

  /// No description provided for @onboardingCheckStatus.
  ///
  /// In ru, this message translates to:
  /// **'Проверить статус'**
  String get onboardingCheckStatus;

  /// No description provided for @onboardingSuspendedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Доступ водителя приостановлен.'**
  String get onboardingSuspendedTitle;

  /// No description provided for @onboardingSuspendedBody.
  ///
  /// In ru, this message translates to:
  /// **'Вы пока не можете принимать заказы. Для уточнения причины обратитесь к администратору MEKEN.'**
  String get onboardingSuspendedBody;

  /// No description provided for @onboardingCheckAgain.
  ///
  /// In ru, this message translates to:
  /// **'Проверить снова'**
  String get onboardingCheckAgain;

  /// No description provided for @onboardingDriverMode.
  ///
  /// In ru, this message translates to:
  /// **'Режим водителя'**
  String get onboardingDriverMode;

  /// No description provided for @onboardingVehicleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Автомобиль водителя'**
  String get onboardingVehicleTitle;

  /// No description provided for @onboardingFillVehicle.
  ///
  /// In ru, this message translates to:
  /// **'Заполните данные автомобиля'**
  String get onboardingFillVehicle;

  /// No description provided for @onboardingVehicleHint.
  ///
  /// In ru, this message translates to:
  /// **'После отправки заявка перейдёт на проверку. Эти сведения увидит пассажир только после принятия заказа.'**
  String get onboardingVehicleHint;

  /// No description provided for @onboardingCarModel.
  ///
  /// In ru, this message translates to:
  /// **'Марка и модель'**
  String get onboardingCarModel;

  /// No description provided for @onboardingCarModelRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите марку и модель автомобиля'**
  String get onboardingCarModelRequired;

  /// No description provided for @onboardingCarColor.
  ///
  /// In ru, this message translates to:
  /// **'Цвет кузова'**
  String get onboardingCarColor;

  /// No description provided for @onboardingCarColorRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите цвет автомобиля'**
  String get onboardingCarColorRequired;

  /// No description provided for @onboardingCarNumber.
  ///
  /// In ru, this message translates to:
  /// **'Государственный номер'**
  String get onboardingCarNumber;

  /// No description provided for @onboardingCarNumberRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите государственный номер'**
  String get onboardingCarNumberRequired;

  /// No description provided for @onboardingSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Отправить заявку на проверку'**
  String get onboardingSubmit;

  /// No description provided for @drawerEnabled.
  ///
  /// In ru, this message translates to:
  /// **'Включен'**
  String get drawerEnabled;

  /// No description provided for @drawerDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Выключен'**
  String get drawerDisabled;

  /// No description provided for @drawerHistory.
  ///
  /// In ru, this message translates to:
  /// **'История заказов'**
  String get drawerHistory;

  /// No description provided for @drawerSignOut.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get drawerSignOut;

  /// No description provided for @deliveryPackage.
  ///
  /// In ru, this message translates to:
  /// **'Посылка: {description}'**
  String deliveryPackage(String description);

  /// No description provided for @deliveryRecipient.
  ///
  /// In ru, this message translates to:
  /// **'Получатель: {name}'**
  String deliveryRecipient(String name);

  /// No description provided for @deliveryPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон: {phone}'**
  String deliveryPhone(String phone);

  /// No description provided for @deliveryCallRecipient.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить получателю'**
  String get deliveryCallRecipient;

  /// No description provided for @deliveryApartment.
  ///
  /// In ru, this message translates to:
  /// **'Квартира: {apartment}'**
  String deliveryApartment(String apartment);

  /// No description provided for @deliveryDialerFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть приложение звонков.'**
  String get deliveryDialerFailed;

  /// No description provided for @intercityKazakhstanTime.
  ///
  /// In ru, this message translates to:
  /// **'{time} · Время Казахстана'**
  String intercityKazakhstanTime(String time);

  /// No description provided for @intercityPassengers.
  ///
  /// In ru, this message translates to:
  /// **'Пассажиров: {count}'**
  String intercityPassengers(int count);

  /// No description provided for @intercityHasLuggage.
  ///
  /// In ru, this message translates to:
  /// **'Есть багаж'**
  String get intercityHasLuggage;

  /// No description provided for @intercityComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий: {comment}'**
  String intercityComment(String comment);

  /// No description provided for @intercityPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена: {price} ₸'**
  String intercityPrice(int price);

  /// No description provided for @intercitySearchCityHint.
  ///
  /// In ru, this message translates to:
  /// **'Город или населённый пункт'**
  String get intercitySearchCityHint;

  /// No description provided for @intercityStreetHouseHint.
  ///
  /// In ru, this message translates to:
  /// **'Улица и дом'**
  String get intercityStreetHouseHint;

  /// No description provided for @intercityChooseOnMap.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать на карте'**
  String get intercityChooseOnMap;

  /// No description provided for @profileWrongPassword.
  ///
  /// In ru, this message translates to:
  /// **'Неверный пароль.'**
  String get profileWrongPassword;

  /// No description provided for @profileTooManyAttempts.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много попыток. Попробуйте позже.'**
  String get profileTooManyAttempts;

  /// No description provided for @profileNetworkError.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения с сетью. Попробуйте ещё раз.'**
  String get profileNetworkError;

  /// No description provided for @profileUserDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Этот аккаунт отключён.'**
  String get profileUserDisabled;

  /// No description provided for @profileUserNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подтвердить текущий аккаунт.'**
  String get profileUserNotFound;

  /// No description provided for @profileRecentLoginRequired.
  ///
  /// In ru, this message translates to:
  /// **'Требуется повторный вход в аккаунт.'**
  String get profileRecentLoginRequired;

  /// No description provided for @profileReauthFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подтвердить пароль.'**
  String get profileReauthFailed;

  /// No description provided for @profileDeletionUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подтвердить результат удаления. Проверьте состояние аккаунта позже.'**
  String get profileDeletionUnknown;

  /// No description provided for @intercityOrderCar.
  ///
  /// In ru, this message translates to:
  /// **'Заказать машину'**
  String get intercityOrderCar;

  /// No description provided for @intercityOrderCarHint.
  ///
  /// In ru, this message translates to:
  /// **'Машина целиком до нужного адреса'**
  String get intercityOrderCarHint;

  /// No description provided for @intercityFindRide.
  ///
  /// In ru, this message translates to:
  /// **'Найти попутку'**
  String get intercityFindRide;

  /// No description provided for @intercityFindRideHint.
  ///
  /// In ru, this message translates to:
  /// **'Забронировать место в поездке водителя'**
  String get intercityFindRideHint;

  /// No description provided for @intercityMyBookings.
  ///
  /// In ru, this message translates to:
  /// **'Мои бронирования'**
  String get intercityMyBookings;

  /// No description provided for @intercityLookingForRide.
  ///
  /// In ru, this message translates to:
  /// **'Ищу попутку'**
  String get intercityLookingForRide;

  /// No description provided for @intercityChooseCities.
  ///
  /// In ru, this message translates to:
  /// **'Выберите города отправления и назначения.'**
  String get intercityChooseCities;

  /// No description provided for @intercityDifferentCities.
  ///
  /// In ru, this message translates to:
  /// **'Города отправления и назначения должны отличаться.'**
  String get intercityDifferentCities;

  /// No description provided for @intercityDatePast.
  ///
  /// In ru, this message translates to:
  /// **'Дата поездки не может быть в прошлом.'**
  String get intercityDatePast;

  /// No description provided for @intercitySeatsRange.
  ///
  /// In ru, this message translates to:
  /// **'Выберите от 1 до 7 мест.'**
  String get intercitySeatsRange;

  /// No description provided for @intercityFrom.
  ///
  /// In ru, this message translates to:
  /// **'Откуда'**
  String get intercityFrom;

  /// No description provided for @intercityTo.
  ///
  /// In ru, this message translates to:
  /// **'Куда'**
  String get intercityTo;

  /// No description provided for @intercityTravelDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата поездки'**
  String get intercityTravelDate;

  /// No description provided for @intercityFindTrips.
  ///
  /// In ru, this message translates to:
  /// **'Найти поездки'**
  String get intercityFindTrips;

  /// No description provided for @intercitySeatCount.
  ///
  /// In ru, this message translates to:
  /// **'Количество мест'**
  String get intercitySeatCount;

  /// No description provided for @intercityDecrease.
  ///
  /// In ru, this message translates to:
  /// **'Уменьшить'**
  String get intercityDecrease;

  /// No description provided for @intercityIncrease.
  ///
  /// In ru, this message translates to:
  /// **'Увеличить'**
  String get intercityIncrease;

  /// No description provided for @intercitySeatSemantics.
  ///
  /// In ru, this message translates to:
  /// **'Количество мест: {count}'**
  String intercitySeatSemantics(int count);

  /// No description provided for @intercityMatchingTrips.
  ///
  /// In ru, this message translates to:
  /// **'Подходящие поездки'**
  String get intercityMatchingTrips;

  /// No description provided for @intercityTripsLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить поездки'**
  String get intercityTripsLoadFailed;

  /// No description provided for @intercityNoTrips.
  ///
  /// In ru, this message translates to:
  /// **'Подходящих поездок пока нет'**
  String get intercityNoTrips;

  /// No description provided for @intercityLeaveRequest.
  ///
  /// In ru, this message translates to:
  /// **'Оставить заявку'**
  String get intercityLeaveRequest;

  /// No description provided for @intercityAvailableSeats.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Свободно: {count} место} few{Свободно: {count} места} many{Свободно: {count} мест} other{Свободно: {count} мест}}'**
  String intercityAvailableSeats(int count);

  /// No description provided for @intercityPerSeat.
  ///
  /// In ru, this message translates to:
  /// **'{price} / место'**
  String intercityPerSeat(String price);

  /// No description provided for @intercityDetails.
  ///
  /// In ru, this message translates to:
  /// **'Подробнее'**
  String get intercityDetails;

  /// No description provided for @datePreviousMonth.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущий месяц'**
  String get datePreviousMonth;

  /// No description provided for @dateNextMonth.
  ///
  /// In ru, this message translates to:
  /// **'Следующий месяц'**
  String get dateNextMonth;

  /// No description provided for @dateDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get dateDone;

  /// No description provided for @historyNoAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес не указан'**
  String get historyNoAddress;

  /// No description provided for @historyDriverRole.
  ///
  /// In ru, this message translates to:
  /// **'Я — водитель'**
  String get historyDriverRole;

  /// No description provided for @historyPassengerRole.
  ///
  /// In ru, this message translates to:
  /// **'Я — пассажир'**
  String get historyPassengerRole;

  /// No description provided for @historyTitle.
  ///
  /// In ru, this message translates to:
  /// **'История поездок'**
  String get historyTitle;

  /// No description provided for @historyLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить историю поездок.'**
  String get historyLoadFailed;

  /// No description provided for @historyEmpty.
  ///
  /// In ru, this message translates to:
  /// **'У вас пока нет завершённых поездок'**
  String get historyEmpty;

  /// No description provided for @historyCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Завершён'**
  String get historyCompleted;

  /// No description provided for @historyCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменён'**
  String get historyCancelled;

  /// No description provided for @historyPrice.
  ///
  /// In ru, this message translates to:
  /// **'{price} ₸'**
  String historyPrice(String price);

  /// No description provided for @driverMapActionFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить заказ. Повторите попытку.'**
  String get driverMapActionFailed;

  /// No description provided for @driverMapRerouteFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось перестроить маршрут'**
  String get driverMapRerouteFailed;

  /// No description provided for @driverMapCustomer.
  ///
  /// In ru, this message translates to:
  /// **'заказчика'**
  String get driverMapCustomer;

  /// No description provided for @driverMapNextLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Следующий заказ принят. Не удалось загрузить данные.'**
  String get driverMapNextLoadFailed;

  /// No description provided for @driverMapNextAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Следующий заказ принят'**
  String get driverMapNextAccepted;

  /// No description provided for @driverMapNextUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Заказ уже недоступен'**
  String get driverMapNextUnavailable;

  /// No description provided for @driverMapOwnPrice.
  ///
  /// In ru, this message translates to:
  /// **'Своя цена'**
  String get driverMapOwnPrice;

  /// No description provided for @driverMapPriceLabel.
  ///
  /// In ru, this message translates to:
  /// **'Цена, ₸'**
  String get driverMapPriceLabel;

  /// No description provided for @driverMapOfferSent.
  ///
  /// In ru, this message translates to:
  /// **'Предложение отправлено пассажиру'**
  String get driverMapOfferSent;

  /// No description provided for @driverMapArrivedAction.
  ///
  /// In ru, this message translates to:
  /// **'Я на месте'**
  String get driverMapArrivedAction;

  /// No description provided for @driverMapPackageReceived.
  ///
  /// In ru, this message translates to:
  /// **'Посылка получена'**
  String get driverMapPackageReceived;

  /// No description provided for @driverMapStartTrip.
  ///
  /// In ru, this message translates to:
  /// **'Начать поездку'**
  String get driverMapStartTrip;

  /// No description provided for @driverMapCompleteDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Завершить доставку'**
  String get driverMapCompleteDelivery;

  /// No description provided for @driverMapCompleteTrip.
  ///
  /// In ru, this message translates to:
  /// **'Завершить поездку'**
  String get driverMapCompleteTrip;

  /// No description provided for @driverMapDeliveryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выполнение доставки'**
  String get driverMapDeliveryTitle;

  /// No description provided for @driverMapIntercityTitle.
  ///
  /// In ru, this message translates to:
  /// **'Междугородняя поездка'**
  String get driverMapIntercityTitle;

  /// No description provided for @driverMapCityTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выполнение заказа'**
  String get driverMapCityTitle;

  /// No description provided for @driverMapCollectPackage.
  ///
  /// In ru, this message translates to:
  /// **'Заберите посылку: {address}'**
  String driverMapCollectPackage(String address);

  /// No description provided for @driverMapClientWaiting.
  ///
  /// In ru, this message translates to:
  /// **'Клиент ожидает: {address}'**
  String driverMapClientWaiting(String address);

  /// No description provided for @orderOfferAcceptFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось принять предложение. Повторите попытку.'**
  String get orderOfferAcceptFailed;

  /// No description provided for @trackingStopped.
  ///
  /// In ru, this message translates to:
  /// **'Отслеживание геопозиции остановлено.'**
  String get trackingStopped;

  /// No description provided for @trackingSignIn.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в аккаунт водителя.'**
  String get trackingSignIn;

  /// No description provided for @trackingEnableServices.
  ///
  /// In ru, this message translates to:
  /// **'Включите службы геолокации.'**
  String get trackingEnableServices;

  /// No description provided for @trackingAllowLocation.
  ///
  /// In ru, this message translates to:
  /// **'Разрешите доступ к геолокации.'**
  String get trackingAllowLocation;

  /// No description provided for @trackingAllowInSettings.
  ///
  /// In ru, this message translates to:
  /// **'Разрешите геолокацию в настройках приложения.'**
  String get trackingAllowInSettings;

  /// No description provided for @trackingPositionFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить или отправить текущую геопозицию.'**
  String get trackingPositionFailed;

  /// No description provided for @driverChangeOffer.
  ///
  /// In ru, this message translates to:
  /// **'Изменить предложение'**
  String get driverChangeOffer;

  /// No description provided for @driverPassengerPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена пассажира: {price} ₸'**
  String driverPassengerPrice(int price);

  /// No description provided for @driverYourPrice.
  ///
  /// In ru, this message translates to:
  /// **'Ваша цена, ₸'**
  String get driverYourPrice;

  /// No description provided for @driverEnterWholeAmount.
  ///
  /// In ru, this message translates to:
  /// **'Введите целую сумму.'**
  String get driverEnterWholeAmount;

  /// No description provided for @driverOfferAbovePrice.
  ///
  /// In ru, this message translates to:
  /// **'Предложение должно быть выше цены пассажира.'**
  String get driverOfferAbovePrice;

  /// No description provided for @driverOfferTooHigh.
  ///
  /// In ru, this message translates to:
  /// **'Цена предложения не может превышать 1 000 000 ₸.'**
  String get driverOfferTooHigh;

  /// No description provided for @driverOfferSent.
  ///
  /// In ru, this message translates to:
  /// **'Предложение {price} ₸ отправлено пассажиру.'**
  String driverOfferSent(int price);

  /// No description provided for @driverOfferFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить предложение. Попробуйте ещё раз.'**
  String get driverOfferFailed;

  /// No description provided for @driverNotAuthenticated.
  ///
  /// In ru, this message translates to:
  /// **'Водитель не авторизован'**
  String get driverNotAuthenticated;

  /// No description provided for @driverOnline.
  ///
  /// In ru, this message translates to:
  /// **'На линии'**
  String get driverOnline;

  /// No description provided for @driverActiveCheckFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось проверить текущий заказ. Проверка повторяется автоматически.'**
  String get driverActiveCheckFailed;

  /// No description provided for @driverNoOrders.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет доступных заказов'**
  String get driverNoOrders;

  /// No description provided for @passenger.
  ///
  /// In ru, this message translates to:
  /// **'Пассажир'**
  String get passenger;

  /// No description provided for @distanceKilometers.
  ///
  /// In ru, this message translates to:
  /// **'{distance} км'**
  String distanceKilometers(String distance);

  /// No description provided for @pricePerKilometer.
  ///
  /// In ru, this message translates to:
  /// **'{price} ₸/км'**
  String pricePerKilometer(int price);

  /// No description provided for @driverYouOffered.
  ///
  /// In ru, this message translates to:
  /// **'Вы предложили {price} ₸'**
  String driverYouOffered(int price);

  /// No description provided for @driverChangePrice.
  ///
  /// In ru, this message translates to:
  /// **'Изменить цену'**
  String get driverChangePrice;

  /// No description provided for @driverAcceptForPrice.
  ///
  /// In ru, this message translates to:
  /// **'Принять за {price} ₸'**
  String driverAcceptForPrice(int price);

  /// No description provided for @driverOrdersForbidden.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к заказам. Профиль водителя должен быть одобрен.'**
  String get driverOrdersForbidden;

  /// No description provided for @driverOrdersConfigFailed.
  ///
  /// In ru, this message translates to:
  /// **'Запрос заказов недоступен. Проверьте настройки сервиса.'**
  String get driverOrdersConfigFailed;

  /// No description provided for @driverOrdersTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не ответил вовремя. Проверка заказов повторится автоматически.'**
  String get driverOrdersTimeout;

  /// No description provided for @driverOrdersLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить доступные заказы. Проверка повторится автоматически.'**
  String get driverOrdersLoadFailed;

  /// No description provided for @bookingCancelTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отменить бронь?'**
  String get bookingCancelTitle;

  /// No description provided for @bookingBack.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get bookingBack;

  /// No description provided for @bookingCancelExplanation.
  ///
  /// In ru, this message translates to:
  /// **'Забронированные места снова станут доступными.'**
  String get bookingCancelExplanation;

  /// No description provided for @bookingCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отменить бронь'**
  String get bookingCancel;

  /// No description provided for @bookingCancelFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отменить бронь. Попробуйте ещё раз.'**
  String get bookingCancelFailed;

  /// No description provided for @bookingLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить бронирования'**
  String get bookingLoadFailed;

  /// No description provided for @bookingEmpty.
  ///
  /// In ru, this message translates to:
  /// **'У вас пока нет бронирований'**
  String get bookingEmpty;

  /// No description provided for @bookingSeatsAndPrice.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} место} few{{count} места} many{{count} мест} other{{count} мест}} · {price}'**
  String bookingSeatsAndPrice(int count, String price);

  /// No description provided for @bookingPickup.
  ///
  /// In ru, this message translates to:
  /// **'Точка посадки: {address}'**
  String bookingPickup(String address);

  /// No description provided for @bookingComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий водителю: {comment}'**
  String bookingComment(String comment);

  /// No description provided for @bookingDriver.
  ///
  /// In ru, this message translates to:
  /// **'Водитель: {name}'**
  String bookingDriver(String name);

  /// No description provided for @bookingPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон: {phone}'**
  String bookingPhone(String phone);

  /// No description provided for @bookingUpcoming.
  ///
  /// In ru, this message translates to:
  /// **'Предстоящие'**
  String get bookingUpcoming;

  /// No description provided for @bookingCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменённые'**
  String get bookingCancelled;

  /// No description provided for @bookingCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Завершённые'**
  String get bookingCompleted;

  /// No description provided for @bookingOther.
  ///
  /// In ru, this message translates to:
  /// **'Другие'**
  String get bookingOther;

  /// No description provided for @profileActiveOrder.
  ///
  /// In ru, this message translates to:
  /// **'Сначала завершите или отмените текущий заказ.'**
  String get profileActiveOrder;

  /// No description provided for @profileActiveDriverOrder.
  ///
  /// In ru, this message translates to:
  /// **'Сначала завершите активный заказ водителя.'**
  String get profileActiveDriverOrder;

  /// No description provided for @profileActiveRide.
  ///
  /// In ru, this message translates to:
  /// **'Сначала завершите или отмените поездку «Попутки».'**
  String get profileActiveRide;

  /// No description provided for @profileActiveBooking.
  ///
  /// In ru, this message translates to:
  /// **'Сначала завершите или отмените бронирование.'**
  String get profileActiveBooking;

  /// No description provided for @profileActiveRideRequest.
  ///
  /// In ru, this message translates to:
  /// **'Сначала отмените активный запрос «Попутки».'**
  String get profileActiveRideRequest;

  /// No description provided for @profileDeletionManualReview.
  ///
  /// In ru, this message translates to:
  /// **'Удаление требует проверки службой поддержки.'**
  String get profileDeletionManualReview;

  /// No description provided for @driverIntercityOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заказы пассажиров'**
  String get driverIntercityOrders;

  /// No description provided for @driverIntercityOrdersHint.
  ///
  /// In ru, this message translates to:
  /// **'Обычные междугородние заказы'**
  String get driverIntercityOrdersHint;

  /// No description provided for @driverIntercityMyRides.
  ///
  /// In ru, this message translates to:
  /// **'Мои поездки'**
  String get driverIntercityMyRides;

  /// No description provided for @driverIntercityMyRidesHint.
  ///
  /// In ru, this message translates to:
  /// **'Опубликованные попутки и бронирования'**
  String get driverIntercityMyRidesHint;

  /// No description provided for @driverIntercityCreateRide.
  ///
  /// In ru, this message translates to:
  /// **'Создать поездку'**
  String get driverIntercityCreateRide;

  /// No description provided for @driverIntercityCreateHint.
  ///
  /// In ru, this message translates to:
  /// **'Опубликовать места для попутчиков'**
  String get driverIntercityCreateHint;

  /// No description provided for @intercityPickupPoint.
  ///
  /// In ru, this message translates to:
  /// **'Точка посадки'**
  String get intercityPickupPoint;

  /// No description provided for @driverRidesEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Вы ещё не публиковали поездки'**
  String get driverRidesEmpty;

  /// No description provided for @driverRideTotalSeats.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Всего {count} место} few{Всего {count} места} many{Всего {count} мест} other{Всего {count} мест}}'**
  String driverRideTotalSeats(int count);

  /// No description provided for @driverRideScheduled.
  ///
  /// In ru, this message translates to:
  /// **'Запланирована'**
  String get driverRideScheduled;

  /// No description provided for @driverRideDeparted.
  ///
  /// In ru, this message translates to:
  /// **'В пути'**
  String get driverRideDeparted;

  /// No description provided for @driverRideCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Завершена'**
  String get driverRideCompleted;

  /// No description provided for @driverRideCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменена'**
  String get driverRideCancelled;

  /// No description provided for @driverRideUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Статус неизвестен'**
  String get driverRideUnknown;

  /// No description provided for @driverRideGroupDeparted.
  ///
  /// In ru, this message translates to:
  /// **'В пути'**
  String get driverRideGroupDeparted;

  /// No description provided for @publicDriverLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить профиль водителя'**
  String get publicDriverLoadFailed;

  /// No description provided for @publicDriverNoRatings.
  ///
  /// In ru, this message translates to:
  /// **'Нет оценок'**
  String get publicDriverNoRatings;

  /// No description provided for @publicDriverRatingCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} оценка} few{{count} оценки} many{{count} оценок} other{{count} оценок}}'**
  String publicDriverRatingCount(int count);

  /// No description provided for @publicDriverReviews.
  ///
  /// In ru, this message translates to:
  /// **'Отзывы'**
  String get publicDriverReviews;

  /// No description provided for @publicDriverNoReviews.
  ///
  /// In ru, this message translates to:
  /// **'Отзывов пока нет'**
  String get publicDriverNoReviews;

  /// No description provided for @ratingTitleDriver.
  ///
  /// In ru, this message translates to:
  /// **'Оцените водителя'**
  String get ratingTitleDriver;

  /// No description provided for @ratingCourierObject.
  ///
  /// In ru, this message translates to:
  /// **'курьера'**
  String get ratingCourierObject;

  /// No description provided for @ratingTitlePassenger.
  ///
  /// In ru, this message translates to:
  /// **'Оцените пассажира'**
  String get ratingTitlePassenger;

  /// No description provided for @ratingTitleName.
  ///
  /// In ru, this message translates to:
  /// **'Оцените {name}'**
  String ratingTitleName(String name);

  /// No description provided for @ratingStarTooltip.
  ///
  /// In ru, this message translates to:
  /// **'{score} из 5'**
  String ratingStarTooltip(int score);

  /// No description provided for @ratingReviewHint.
  ///
  /// In ru, this message translates to:
  /// **'Напишите отзыв (необязательно)'**
  String get ratingReviewHint;

  /// No description provided for @ratingCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get ratingCancel;

  /// No description provided for @ratingSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get ratingSubmit;

  /// No description provided for @ratingInvalidRequest.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка в данных или параметрах запроса.'**
  String get ratingInvalidRequest;

  /// No description provided for @ratingForbidden.
  ///
  /// In ru, this message translates to:
  /// **'У вас недостаточно прав для оценки.'**
  String get ratingForbidden;

  /// No description provided for @ratingOrderMissing.
  ///
  /// In ru, this message translates to:
  /// **'Заказ для оценивания не найден.'**
  String get ratingOrderMissing;

  /// No description provided for @ratingAlreadySent.
  ///
  /// In ru, this message translates to:
  /// **'Оценка по этому заказу уже отправлена.'**
  String get ratingAlreadySent;

  /// No description provided for @ratingNotCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Можно оценивать только завершённый заказ.'**
  String get ratingNotCompleted;

  /// No description provided for @ratingInvalidScore.
  ///
  /// In ru, this message translates to:
  /// **'Поставьте оценку от 1 до 5. Отзыв — не более 500 символов.'**
  String get ratingInvalidScore;

  /// No description provided for @ratingFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить оценку. Попробуйте ещё раз.'**
  String get ratingFailed;

  /// No description provided for @mapSelectedPoint.
  ///
  /// In ru, this message translates to:
  /// **'Выбранная точка'**
  String get mapSelectedPoint;

  /// No description provided for @mapPickupMarker.
  ///
  /// In ru, this message translates to:
  /// **'Точка подачи'**
  String get mapPickupMarker;

  /// No description provided for @mapDestinationMarker.
  ///
  /// In ru, this message translates to:
  /// **'Точка назначения'**
  String get mapDestinationMarker;

  /// No description provided for @mapUserMarker.
  ///
  /// In ru, this message translates to:
  /// **'Ваше местоположение'**
  String get mapUserMarker;

  /// No description provided for @mapCourierMarker.
  ///
  /// In ru, this message translates to:
  /// **'Курьер на карте'**
  String get mapCourierMarker;

  /// No description provided for @mapVehicleMarker.
  ///
  /// In ru, this message translates to:
  /// **'Автомобиль на карте'**
  String get mapVehicleMarker;

  /// No description provided for @intercityPickupPrompt.
  ///
  /// In ru, this message translates to:
  /// **'Откуда вас забрать?'**
  String get intercityPickupPrompt;

  /// No description provided for @requestSelectOriginFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сначала выберите город отправления.'**
  String get requestSelectOriginFirst;

  /// No description provided for @requestFutureDate.
  ///
  /// In ru, this message translates to:
  /// **'Заявку можно оставить только на будущую дату.'**
  String get requestFutureDate;

  /// No description provided for @requestCommentTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий не должен превышать 1000 символов.'**
  String get requestCommentTooLong;

  /// No description provided for @requestSelectPickup.
  ///
  /// In ru, this message translates to:
  /// **'Выберите точку посадки.'**
  String get requestSelectPickup;

  /// No description provided for @requestSaved.
  ///
  /// In ru, this message translates to:
  /// **'Заявка сохранена'**
  String get requestSaved;

  /// No description provided for @requestDuplicate.
  ///
  /// In ru, this message translates to:
  /// **'Такая активная заявка уже существует.'**
  String get requestDuplicate;

  /// No description provided for @requestSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить заявку. Попробуйте ещё раз.'**
  String get requestSaveFailed;

  /// No description provided for @requestCancelTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отменить заявку?'**
  String get requestCancelTitle;

  /// No description provided for @requestCancelFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отменить заявку. Попробуйте ещё раз.'**
  String get requestCancelFailed;

  /// No description provided for @requestNotifyHint.
  ///
  /// In ru, this message translates to:
  /// **'Сообщим, когда появится подходящая поездка.'**
  String get requestNotifyHint;

  /// No description provided for @requestCommentLabel.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий водителю (необязательно)'**
  String get requestCommentLabel;

  /// No description provided for @requestCommentHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, подъедьте к главному входу'**
  String get requestCommentHint;

  /// No description provided for @requestMyRequests.
  ///
  /// In ru, this message translates to:
  /// **'Мои заявки'**
  String get requestMyRequests;

  /// No description provided for @requestLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить заявки'**
  String get requestLoadFailed;

  /// No description provided for @requestEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Активных заявок пока нет'**
  String get requestEmpty;

  /// No description provided for @requestDateSeats.
  ///
  /// In ru, this message translates to:
  /// **'{date} · {count, plural, one{{count} место} few{{count} места} many{{count} мест} other{{count} мест}}'**
  String requestDateSeats(String date, int count);

  /// No description provided for @requestMatchedRides.
  ///
  /// In ru, this message translates to:
  /// **'Найдены поездки:'**
  String get requestMatchedRides;

  /// No description provided for @requestMatchedRide.
  ///
  /// In ru, this message translates to:
  /// **'Поездка {number}'**
  String requestMatchedRide(int number);

  /// No description provided for @requestCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отменить заявку'**
  String get requestCancel;

  /// No description provided for @requestActive.
  ///
  /// In ru, this message translates to:
  /// **'Активна'**
  String get requestActive;

  /// No description provided for @requestCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменена'**
  String get requestCancelled;

  /// No description provided for @requestExpired.
  ///
  /// In ru, this message translates to:
  /// **'Истекла'**
  String get requestExpired;

  /// No description provided for @recoveryCheckFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось проверить профиль. Проверьте интернет и повторите.'**
  String get recoveryCheckFailed;

  /// No description provided for @recoveryNameLimit.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя длиной не более 80 символов.'**
  String get recoveryNameLimit;

  /// No description provided for @recoveryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Восстановление профиля'**
  String get recoveryTitle;

  /// No description provided for @recoveryLegacyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль имеет старый формат'**
  String get recoveryLegacyTitle;

  /// No description provided for @recoveryEnterName.
  ///
  /// In ru, this message translates to:
  /// **'Укажите имя'**
  String get recoveryEnterName;

  /// No description provided for @recoveryIncomplete.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось завершить проверку'**
  String get recoveryIncomplete;

  /// No description provided for @recoveryAdminBody.
  ///
  /// In ru, this message translates to:
  /// **'Защищённые поля нельзя безопасно восстановить с телефона. Для этого профиля требуется точечная административная миграция.'**
  String get recoveryAdminBody;

  /// No description provided for @recoveryAdminFields.
  ///
  /// In ru, this message translates to:
  /// **'Требуют административного восстановления:'**
  String get recoveryAdminFields;

  /// No description provided for @recoveryLegacyWarning.
  ///
  /// In ru, this message translates to:
  /// **'Старые isDriver, driverActiveUntil и данные автомобиля обнаружены, но не используются для выдачи водительских прав.'**
  String get recoveryLegacyWarning;

  /// No description provided for @recoveryNameBody.
  ///
  /// In ru, this message translates to:
  /// **'Имя отсутствует в профиле и Firebase Auth. Введите своё имя — остальные защищённые поля останутся без изменений.'**
  String get recoveryNameBody;

  /// No description provided for @recoverySaveContinue.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить и продолжить'**
  String get recoverySaveContinue;

  /// No description provided for @recoveryCheckAgain.
  ///
  /// In ru, this message translates to:
  /// **'Проверить снова'**
  String get recoveryCheckAgain;

  /// No description provided for @recoverySignOut.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта'**
  String get recoverySignOut;

  /// No description provided for @recoveryFieldUid.
  ///
  /// In ru, this message translates to:
  /// **'идентификатор аккаунта (uid)'**
  String get recoveryFieldUid;

  /// No description provided for @recoveryFieldName.
  ///
  /// In ru, this message translates to:
  /// **'имя'**
  String get recoveryFieldName;

  /// No description provided for @recoveryFieldPhone.
  ///
  /// In ru, this message translates to:
  /// **'подтверждённый телефон'**
  String get recoveryFieldPhone;

  /// No description provided for @recoveryFieldRole.
  ///
  /// In ru, this message translates to:
  /// **'базовая роль passenger'**
  String get recoveryFieldRole;

  /// No description provided for @recoveryFieldRating.
  ///
  /// In ru, this message translates to:
  /// **'начальный рейтинг 5.0'**
  String get recoveryFieldRating;

  /// No description provided for @recoveryFieldCreatedAt.
  ///
  /// In ru, this message translates to:
  /// **'дата создания из Firebase Auth'**
  String get recoveryFieldCreatedAt;

  /// No description provided for @driverRideUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Поездка обновлена'**
  String get driverRideUpdated;

  /// No description provided for @driverRidePublished.
  ///
  /// In ru, this message translates to:
  /// **'Поездка опубликована'**
  String get driverRidePublished;

  /// No description provided for @driverRideEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать поездку'**
  String get driverRideEditTitle;

  /// No description provided for @driverRideCreateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Создать поездку'**
  String get driverRideCreateTitle;

  /// No description provided for @driverRideProtected.
  ///
  /// In ru, this message translates to:
  /// **'Маршрут, время и количество мест нельзя изменить после бронирования.'**
  String get driverRideProtected;

  /// No description provided for @driverRideRoute.
  ///
  /// In ru, this message translates to:
  /// **'Маршрут'**
  String get driverRideRoute;

  /// No description provided for @driverRideDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get driverRideDate;

  /// No description provided for @driverRideTime.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get driverRideTime;

  /// No description provided for @driverRidePricePerSeat.
  ///
  /// In ru, this message translates to:
  /// **'Цена за место'**
  String get driverRidePricePerSeat;

  /// No description provided for @driverRidePriceNotice.
  ///
  /// In ru, this message translates to:
  /// **'Новая цена не изменит сумму уже созданных бронирований.'**
  String get driverRidePriceNotice;

  /// No description provided for @driverRideLuggageAllowed.
  ///
  /// In ru, this message translates to:
  /// **'Багаж разрешён'**
  String get driverRideLuggageAllowed;

  /// No description provided for @driverRideNoLuggage.
  ///
  /// In ru, this message translates to:
  /// **'Без багажа'**
  String get driverRideNoLuggage;

  /// No description provided for @driverRideComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий'**
  String get driverRideComment;

  /// No description provided for @driverRidePublish.
  ///
  /// In ru, this message translates to:
  /// **'Опубликовать поездку'**
  String get driverRidePublish;

  /// No description provided for @driverRideChooseCities.
  ///
  /// In ru, this message translates to:
  /// **'Выберите города отправления и назначения.'**
  String get driverRideChooseCities;

  /// No description provided for @driverRideDifferentCities.
  ///
  /// In ru, this message translates to:
  /// **'Города отправления и назначения должны отличаться.'**
  String get driverRideDifferentCities;

  /// No description provided for @driverRideFutureTime.
  ///
  /// In ru, this message translates to:
  /// **'Выберите будущую дату и время.'**
  String get driverRideFutureTime;

  /// No description provided for @driverRideSeatsRange.
  ///
  /// In ru, this message translates to:
  /// **'Можно предложить от 1 до 7 мест.'**
  String get driverRideSeatsRange;

  /// No description provided for @driverRideInvalidPrice.
  ///
  /// In ru, this message translates to:
  /// **'Укажите корректную цену за место.'**
  String get driverRideInvalidPrice;

  /// No description provided for @driverRideCommentLong.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий слишком длинный.'**
  String get driverRideCommentLong;

  /// No description provided for @driverRideInvalidData.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте данные поездки.'**
  String get driverRideInvalidData;

  /// No description provided for @driverRideLogin.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в аккаунт и повторите.'**
  String get driverRideLogin;

  /// No description provided for @driverRideAccess.
  ///
  /// In ru, this message translates to:
  /// **'Доступ водителя не активен.'**
  String get driverRideAccess;

  /// No description provided for @driverRideMissing.
  ///
  /// In ru, this message translates to:
  /// **'Поездка не найдена.'**
  String get driverRideMissing;

  /// No description provided for @driverRideChanged.
  ///
  /// In ru, this message translates to:
  /// **'Поездка уже изменилась. Обновите данные.'**
  String get driverRideChanged;

  /// No description provided for @driverRideSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить поездку.'**
  String get driverRideSaveFailed;

  /// No description provided for @driverRideServerTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не ответил. Повторите позже.'**
  String get driverRideServerTimeout;

  /// No description provided for @bookingPickupCityFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось определить город посадки.'**
  String get bookingPickupCityFailed;

  /// No description provided for @bookingSelectPickup.
  ///
  /// In ru, this message translates to:
  /// **'Выберите точку посадки.'**
  String get bookingSelectPickup;

  /// No description provided for @bookingCommentLimit.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий не должен превышать 1000 символов.'**
  String get bookingCommentLimit;

  /// No description provided for @bookingConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить бронирование?'**
  String get bookingConfirmTitle;

  /// No description provided for @bookingBook.
  ///
  /// In ru, this message translates to:
  /// **'Забронировать'**
  String get bookingBook;

  /// No description provided for @bookingBooked.
  ///
  /// In ru, this message translates to:
  /// **'Место забронировано'**
  String get bookingBooked;

  /// No description provided for @bookingSavedBody.
  ///
  /// In ru, this message translates to:
  /// **'Бронь сохранена в разделе «Мои бронирования».'**
  String get bookingSavedBody;

  /// No description provided for @bookingStay.
  ///
  /// In ru, this message translates to:
  /// **'Остаться'**
  String get bookingStay;

  /// No description provided for @bookingRide.
  ///
  /// In ru, this message translates to:
  /// **'Поездка'**
  String get bookingRide;

  /// No description provided for @bookingLoadRideFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить поездку'**
  String get bookingLoadRideFailed;

  /// No description provided for @bookingTotal.
  ///
  /// In ru, this message translates to:
  /// **'Итого: {price}'**
  String bookingTotal(String price);

  /// No description provided for @bookingBookSeats.
  ///
  /// In ru, this message translates to:
  /// **'Забронировать {count, plural, one{{count} место} few{{count} места} many{{count} мест} other{{count} мест}}'**
  String bookingBookSeats(int count);

  /// No description provided for @bookingConfirmSummary.
  ///
  /// In ru, this message translates to:
  /// **'{seats} · {price}\n{address}'**
  String bookingConfirmSummary(String seats, String price, String address);

  /// No description provided for @bookingRideChanged.
  ///
  /// In ru, this message translates to:
  /// **'Поездка изменилась или свободных мест уже недостаточно.'**
  String get bookingRideChanged;

  /// No description provided for @bookingLogin.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в аккаунт и повторите попытку.'**
  String get bookingLogin;

  /// No description provided for @bookingServerTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не ответил. Повторите попытку.'**
  String get bookingServerTimeout;

  /// No description provided for @bookingFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось забронировать место. Повторите попытку.'**
  String get bookingFailed;

  /// No description provided for @driverRideDetailsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Детали поездки'**
  String get driverRideDetailsTitle;

  /// No description provided for @driverRideStatusLabel.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get driverRideStatusLabel;

  /// No description provided for @driverRideDeparture.
  ///
  /// In ru, this message translates to:
  /// **'Отправление'**
  String get driverRideDeparture;

  /// No description provided for @driverRideTotalSeatsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Мест всего'**
  String get driverRideTotalSeatsLabel;

  /// No description provided for @driverRideAvailableSeatsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Свободно мест'**
  String get driverRideAvailableSeatsLabel;

  /// No description provided for @driverRideBookedSeatsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Забронировано мест'**
  String get driverRideBookedSeatsLabel;

  /// No description provided for @driverRideLuggage.
  ///
  /// In ru, this message translates to:
  /// **'Багаж'**
  String get driverRideLuggage;

  /// No description provided for @driverRideYes.
  ///
  /// In ru, this message translates to:
  /// **'Разрешён'**
  String get driverRideYes;

  /// No description provided for @driverRideNo.
  ///
  /// In ru, this message translates to:
  /// **'Нет'**
  String get driverRideNo;

  /// No description provided for @driverRideVehicle.
  ///
  /// In ru, this message translates to:
  /// **'Автомобиль'**
  String get driverRideVehicle;

  /// No description provided for @driverRidePassengers.
  ///
  /// In ru, this message translates to:
  /// **'Пассажиры'**
  String get driverRidePassengers;

  /// No description provided for @driverRideNoBookings.
  ///
  /// In ru, this message translates to:
  /// **'Пока никто не забронировал место'**
  String get driverRideNoBookings;

  /// No description provided for @driverRideCancelTrip.
  ///
  /// In ru, this message translates to:
  /// **'Отменить поездку'**
  String get driverRideCancelTrip;

  /// No description provided for @driverRideStartTrip.
  ///
  /// In ru, this message translates to:
  /// **'Начать поездку'**
  String get driverRideStartTrip;

  /// No description provided for @driverRideFinishTrip.
  ///
  /// In ru, this message translates to:
  /// **'Завершить поездку'**
  String get driverRideFinishTrip;

  /// No description provided for @driverRideBookingConfirmed.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждено'**
  String get driverRideBookingConfirmed;

  /// No description provided for @driverRideBookingCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменено'**
  String get driverRideBookingCancelled;

  /// No description provided for @driverRideBookingCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Завершено'**
  String get driverRideBookingCompleted;

  /// No description provided for @driverRideBookingUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Статус неизвестен'**
  String get driverRideBookingUnknown;

  /// No description provided for @driverRideCancelTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отменить поездку?'**
  String get driverRideCancelTitle;

  /// No description provided for @driverRideDepartTitle.
  ///
  /// In ru, this message translates to:
  /// **'Начать поездку?'**
  String get driverRideDepartTitle;

  /// No description provided for @driverRideCompleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Завершить поездку?'**
  String get driverRideCompleteTitle;

  /// No description provided for @driverRideCancelAction.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get driverRideCancelAction;

  /// No description provided for @driverRideDepartAction.
  ///
  /// In ru, this message translates to:
  /// **'Начать'**
  String get driverRideDepartAction;

  /// No description provided for @driverRideCompleteAction.
  ///
  /// In ru, this message translates to:
  /// **'Завершить'**
  String get driverRideCompleteAction;

  /// No description provided for @driverRideCancelBookingsWarning.
  ///
  /// In ru, this message translates to:
  /// **'Все бронирования пассажиров будут отменены.'**
  String get driverRideCancelBookingsWarning;

  /// No description provided for @driverRideCancelNoBookings.
  ///
  /// In ru, this message translates to:
  /// **'Поездка больше не будет доступна пассажирам.'**
  String get driverRideCancelNoBookings;

  /// No description provided for @driverRideDepartWarning.
  ///
  /// In ru, this message translates to:
  /// **'После отправления новые бронирования и отмена пассажиром будут недоступны.'**
  String get driverRideDepartWarning;

  /// No description provided for @driverRideCompleteWarning.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердите завершение поездки.'**
  String get driverRideCompleteWarning;

  /// No description provided for @driverRideBookingSummary.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} место} few{{count} места} many{{count} мест} other{{count} мест}} · {price}'**
  String driverRideBookingSummary(int count, String price);

  /// No description provided for @driverRidePassengerName.
  ///
  /// In ru, this message translates to:
  /// **'Пассажир: {name}'**
  String driverRidePassengerName(String name);

  /// No description provided for @driverRidePickupComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий пассажира: {comment}'**
  String driverRidePickupComment(String comment);

  /// No description provided for @driverRideShowMap.
  ///
  /// In ru, this message translates to:
  /// **'Показать на карте'**
  String get driverRideShowMap;

  /// No description provided for @navigationGpsRequired.
  ///
  /// In ru, this message translates to:
  /// **'Необходимо разрешение на доступ к GPS'**
  String get navigationGpsRequired;

  /// No description provided for @navigationRecalculating.
  ///
  /// In ru, this message translates to:
  /// **'Перестраиваем маршрут...'**
  String get navigationRecalculating;

  /// No description provided for @navigationRecalculateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось перестроить маршрут.'**
  String get navigationRecalculateFailed;

  /// No description provided for @navigationTitle.
  ///
  /// In ru, this message translates to:
  /// **'Навигация заказа'**
  String get navigationTitle;

  /// No description provided for @navigationMapPlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'Карта здесь отображается'**
  String get navigationMapPlaceholder;

  /// No description provided for @timePickerChoose.
  ///
  /// In ru, this message translates to:
  /// **'Выберите время'**
  String get timePickerChoose;

  /// No description provided for @timePickerHours.
  ///
  /// In ru, this message translates to:
  /// **'Часы'**
  String get timePickerHours;

  /// No description provided for @timePickerMinutes.
  ///
  /// In ru, this message translates to:
  /// **'Минуты'**
  String get timePickerMinutes;

  /// No description provided for @timePickerDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get timePickerDone;

  /// No description provided for @nextOrderNearby.
  ///
  /// In ru, this message translates to:
  /// **'Следующий заказ рядом'**
  String get nextOrderNearby;

  /// No description provided for @nextOrderDistance.
  ///
  /// In ru, this message translates to:
  /// **'Подача в {meters} м'**
  String nextOrderDistance(int meters);

  /// No description provided for @nextOrderOwnPrice.
  ///
  /// In ru, this message translates to:
  /// **'Своя цена'**
  String get nextOrderOwnPrice;

  /// No description provided for @nextOrderAccept.
  ///
  /// In ru, this message translates to:
  /// **'Принять'**
  String get nextOrderAccept;

  /// No description provided for @registerUnexpectedError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось зарегистрироваться. Попробуйте ещё раз.'**
  String get registerUnexpectedError;

  /// No description provided for @driverOrderUpdateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить статус заказа. Попробуйте ещё раз.'**
  String get driverOrderUpdateFailed;

  /// No description provided for @driverOrderHeading.
  ///
  /// In ru, this message translates to:
  /// **'Едем к клиенту'**
  String get driverOrderHeading;

  /// No description provided for @driverOrderWaiting.
  ///
  /// In ru, this message translates to:
  /// **'Ожидание клиента'**
  String get driverOrderWaiting;

  /// No description provided for @driverOrderInProgress.
  ///
  /// In ru, this message translates to:
  /// **'Поездка в процессе'**
  String get driverOrderInProgress;

  /// No description provided for @driverOrderAtPickup.
  ///
  /// In ru, this message translates to:
  /// **'На месте'**
  String get driverOrderAtPickup;

  /// No description provided for @driverOrderStart.
  ///
  /// In ru, this message translates to:
  /// **'Начать поездку'**
  String get driverOrderStart;

  /// No description provided for @driverOrderFinish.
  ///
  /// In ru, this message translates to:
  /// **'Завершить поездку'**
  String get driverOrderFinish;

  /// No description provided for @driverOrderCost.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость:'**
  String get driverOrderCost;

  /// No description provided for @bookingSeats.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} место} few{{count} места} many{{count} мест} other{{count} мест}}'**
  String bookingSeats(int count);

  /// No description provided for @navContinueToPoint.
  ///
  /// In ru, this message translates to:
  /// **'Продолжайте к точке'**
  String get navContinueToPoint;

  /// No description provided for @navArrived.
  ///
  /// In ru, this message translates to:
  /// **'Вы прибыли'**
  String get navArrived;

  /// No description provided for @navDepart.
  ///
  /// In ru, this message translates to:
  /// **'Начните движение'**
  String get navDepart;

  /// No description provided for @navExitRoundabout.
  ///
  /// In ru, this message translates to:
  /// **'Съезжайте с кольца'**
  String get navExitRoundabout;

  /// No description provided for @navEnterRoundabout.
  ///
  /// In ru, this message translates to:
  /// **'Въезжайте на кольцо'**
  String get navEnterRoundabout;

  /// No description provided for @navRoundaboutExit.
  ///
  /// In ru, this message translates to:
  /// **'На кольце сверните на {exitNumber}-й съезд'**
  String navRoundaboutExit(int exitNumber);

  /// No description provided for @navUTurn.
  ///
  /// In ru, this message translates to:
  /// **'Развернитесь'**
  String get navUTurn;

  /// No description provided for @navKeepLeft.
  ///
  /// In ru, this message translates to:
  /// **'Держитесь левее'**
  String get navKeepLeft;

  /// No description provided for @navKeepRight.
  ///
  /// In ru, this message translates to:
  /// **'Держитесь правее'**
  String get navKeepRight;

  /// No description provided for @navContinue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжайте движение'**
  String get navContinue;

  /// No description provided for @navMergeLeft.
  ///
  /// In ru, this message translates to:
  /// **'Влейтесь в поток слева'**
  String get navMergeLeft;

  /// No description provided for @navMergeRight.
  ///
  /// In ru, this message translates to:
  /// **'Влейтесь в поток справа'**
  String get navMergeRight;

  /// No description provided for @navMerge.
  ///
  /// In ru, this message translates to:
  /// **'Влейтесь в поток'**
  String get navMerge;

  /// No description provided for @navOnRamp.
  ///
  /// In ru, this message translates to:
  /// **'Выезжайте на съезд'**
  String get navOnRamp;

  /// No description provided for @navOffRamp.
  ///
  /// In ru, this message translates to:
  /// **'Сверните на съезд'**
  String get navOffRamp;

  /// No description provided for @navStraight.
  ///
  /// In ru, this message translates to:
  /// **'Продолжайте прямо'**
  String get navStraight;

  /// No description provided for @navTurnSharpLeft.
  ///
  /// In ru, this message translates to:
  /// **'Резко поверните налево'**
  String get navTurnSharpLeft;

  /// No description provided for @navTurnSharpRight.
  ///
  /// In ru, this message translates to:
  /// **'Резко поверните направо'**
  String get navTurnSharpRight;

  /// No description provided for @navTurnSlightLeft.
  ///
  /// In ru, this message translates to:
  /// **'Плавно поверните налево'**
  String get navTurnSlightLeft;

  /// No description provided for @navTurnSlightRight.
  ///
  /// In ru, this message translates to:
  /// **'Плавно поверните направо'**
  String get navTurnSlightRight;

  /// No description provided for @navTurnLeft.
  ///
  /// In ru, this message translates to:
  /// **'Поверните налево'**
  String get navTurnLeft;

  /// No description provided for @navTurnRight.
  ///
  /// In ru, this message translates to:
  /// **'Поверните направо'**
  String get navTurnRight;

  /// No description provided for @navDistanceMeters.
  ///
  /// In ru, this message translates to:
  /// **'Через {value} м'**
  String navDistanceMeters(int value);

  /// No description provided for @navDistanceKilometers.
  ///
  /// In ru, this message translates to:
  /// **'Через {value} км'**
  String navDistanceKilometers(String value);

  /// No description provided for @navMetersShort.
  ///
  /// In ru, this message translates to:
  /// **'{value} м'**
  String navMetersShort(int value);

  /// No description provided for @navKilometersShort.
  ///
  /// In ru, this message translates to:
  /// **'{value} км'**
  String navKilometersShort(String value);

  /// No description provided for @navMinutesShort.
  ///
  /// In ru, this message translates to:
  /// **'{value} мин'**
  String navMinutesShort(int value);

  /// No description provided for @navHoursMinutesShort.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч {minutes} мин'**
  String navHoursMinutesShort(int hours, int minutes);

  /// No description provided for @navRemaining.
  ///
  /// In ru, this message translates to:
  /// **'Осталось: {summary}'**
  String navRemaining(String summary);

  /// No description provided for @mapAddAddress.
  ///
  /// In ru, this message translates to:
  /// **'Добавить адрес'**
  String get mapAddAddress;

  /// No description provided for @mapStopNumber.
  ///
  /// In ru, this message translates to:
  /// **'Остановка {number}'**
  String mapStopNumber(int number);

  /// No description provided for @mapFinalDestination.
  ///
  /// In ru, this message translates to:
  /// **'Конечная точка'**
  String get mapFinalDestination;

  /// No description provided for @mapRemoveStop.
  ///
  /// In ru, this message translates to:
  /// **'Удалить остановку'**
  String get mapRemoveStop;

  /// No description provided for @mapChooseAllStops.
  ///
  /// In ru, this message translates to:
  /// **'Выберите адрес для каждой остановки.'**
  String get mapChooseAllStops;

  /// No description provided for @driverMapNextStop.
  ///
  /// In ru, this message translates to:
  /// **'Следующая остановка'**
  String get driverMapNextStop;

  /// No description provided for @intercityOpenChat.
  ///
  /// In ru, this message translates to:
  /// **'Открыть чат'**
  String get intercityOpenChat;

  /// No description provided for @intercityWhatsApp.
  ///
  /// In ru, this message translates to:
  /// **'Написать в WhatsApp'**
  String get intercityWhatsApp;

  /// No description provided for @intercityWhatsAppUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть WhatsApp.'**
  String get intercityWhatsAppUnavailable;

  /// No description provided for @intercityNavigationUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Для этого рейса не указаны координаты конечной точки.'**
  String get intercityNavigationUnavailable;

  /// No description provided for @intercityNavigationTitle.
  ///
  /// In ru, this message translates to:
  /// **'Навигация межгород'**
  String get intercityNavigationTitle;

  /// No description provided for @intercityNextPoint.
  ///
  /// In ru, this message translates to:
  /// **'Следующая точка'**
  String get intercityNextPoint;

  /// No description provided for @intercityFinishRide.
  ///
  /// In ru, this message translates to:
  /// **'Завершить поездку'**
  String get intercityFinishRide;

  /// No description provided for @pushIntercityTripCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Междугородняя поездка завершена'**
  String get pushIntercityTripCompleted;

  /// No description provided for @pushIntercityChatMessage.
  ///
  /// In ru, this message translates to:
  /// **'Новое сообщение по поездке'**
  String get pushIntercityChatMessage;

  /// No description provided for @intercityContinueActiveTrip.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить поездку'**
  String get intercityContinueActiveTrip;

  /// No description provided for @intercityMarkPickupReached.
  ///
  /// In ru, this message translates to:
  /// **'Пассажир забран'**
  String get intercityMarkPickupReached;

  /// No description provided for @intercityPickupReached.
  ///
  /// In ru, this message translates to:
  /// **'Пассажир уже забран'**
  String get intercityPickupReached;

  /// No description provided for @intercityActiveTripUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось проверить активную поездку. Попробуйте ещё раз.'**
  String get intercityActiveTripUnknown;

  /// No description provided for @cityCancelTripTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отменить поездку?'**
  String get cityCancelTripTitle;

  /// No description provided for @cityCancelTripWarning.
  ///
  /// In ru, this message translates to:
  /// **'Поездка уже началась. Отменяйте её только при необходимости.'**
  String get cityCancelTripWarning;

  /// No description provided for @cityCancelReasonLabel.
  ///
  /// In ru, this message translates to:
  /// **'Выберите причину отмены'**
  String get cityCancelReasonLabel;

  /// No description provided for @cityCancelReasonRequired.
  ///
  /// In ru, this message translates to:
  /// **'Выберите причину отмены поездки.'**
  String get cityCancelReasonRequired;

  /// No description provided for @cityCancelReasonPlansChanged.
  ///
  /// In ru, this message translates to:
  /// **'Изменились планы'**
  String get cityCancelReasonPlansChanged;

  /// No description provided for @cityCancelReasonCarProblem.
  ///
  /// In ru, this message translates to:
  /// **'Проблема с автомобилем'**
  String get cityCancelReasonCarProblem;

  /// No description provided for @cityCancelReasonDriverProblem.
  ///
  /// In ru, this message translates to:
  /// **'Проблема с водителем'**
  String get cityCancelReasonDriverProblem;

  /// No description provided for @cityCancelReasonCarBreakdown.
  ///
  /// In ru, this message translates to:
  /// **'Поломка автомобиля'**
  String get cityCancelReasonCarBreakdown;

  /// No description provided for @cityCancelReasonRoadIncident.
  ///
  /// In ru, this message translates to:
  /// **'ДТП / дорожная ситуация'**
  String get cityCancelReasonRoadIncident;

  /// No description provided for @cityCancelReasonPassengerRequested.
  ///
  /// In ru, this message translates to:
  /// **'Пассажир попросил отменить'**
  String get cityCancelReasonPassengerRequested;

  /// No description provided for @cityCancelReasonPassengerProblem.
  ///
  /// In ru, this message translates to:
  /// **'Проблема с пассажиром'**
  String get cityCancelReasonPassengerProblem;

  /// No description provided for @cityCancelReasonEmergency.
  ///
  /// In ru, this message translates to:
  /// **'Экстренная ситуация'**
  String get cityCancelReasonEmergency;

  /// No description provided for @cityCancelReasonOther.
  ///
  /// In ru, this message translates to:
  /// **'Другая причина'**
  String get cityCancelReasonOther;

  /// No description provided for @cityCancelReasonDetails.
  ///
  /// In ru, this message translates to:
  /// **'Опишите причину (необязательно)'**
  String get cityCancelReasonDetails;

  /// No description provided for @cityCancelFinalConfirmation.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить отмену начавшейся поездки?'**
  String get cityCancelFinalConfirmation;

  /// No description provided for @pushCityCancelledByPassenger.
  ///
  /// In ru, this message translates to:
  /// **'Заказ отменён пассажиром'**
  String get pushCityCancelledByPassenger;

  /// No description provided for @pushCityCancelledByDriver.
  ///
  /// In ru, this message translates to:
  /// **'Водитель отменил поездку'**
  String get pushCityCancelledByDriver;

  /// No description provided for @deliveryRouteSection.
  ///
  /// In ru, this message translates to:
  /// **'Маршрут'**
  String get deliveryRouteSection;

  /// No description provided for @deliveryParcelSection.
  ///
  /// In ru, this message translates to:
  /// **'Что доставляем'**
  String get deliveryParcelSection;

  /// No description provided for @deliveryContactsSection.
  ///
  /// In ru, this message translates to:
  /// **'Контакты'**
  String get deliveryContactsSection;

  /// No description provided for @deliverySenderSection.
  ///
  /// In ru, this message translates to:
  /// **'Отправитель'**
  String get deliverySenderSection;

  /// No description provided for @deliverySenderCurrentUser.
  ///
  /// In ru, this message translates to:
  /// **'Вы — пользователь, оформляющий заказ'**
  String get deliverySenderCurrentUser;

  /// No description provided for @deliveryRecipientSection.
  ///
  /// In ru, this message translates to:
  /// **'Получатель'**
  String get deliveryRecipientSection;

  /// No description provided for @deliveryAdditionalSection.
  ///
  /// In ru, this message translates to:
  /// **'Дополнительные детали'**
  String get deliveryAdditionalSection;

  /// No description provided for @deliveryDetailsFilled.
  ///
  /// In ru, this message translates to:
  /// **'Заполнено'**
  String get deliveryDetailsFilled;

  /// No description provided for @deliveryPriceSection.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость доставки'**
  String get deliveryPriceSection;

  /// No description provided for @driverWorkCity.
  ///
  /// In ru, this message translates to:
  /// **'Город работы'**
  String get driverWorkCity;

  /// No description provided for @driverWorkCityChangeFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сменить город работы. Завершите активную поездку или попробуйте позже.'**
  String get driverWorkCityChangeFailed;

  /// No description provided for @citiesUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить список городов. Попробуйте ещё раз.'**
  String get citiesUnavailable;

  /// No description provided for @termsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Условия использования'**
  String get termsTitle;

  /// No description provided for @termsBody.
  ///
  /// In ru, this message translates to:
  /// **'Версия {version}. Перед публикацией сообщений, отзывов и другого контента ознакомьтесь с условиями MEKEN. Не публикуйте оскорбления, угрозы, спам, незаконный или опасный контент. Вы можете пожаловаться на контент или заблокировать другого пользователя. Полный текст сохранён в документах MEKEN.'**
  String termsBody(String version);

  /// No description provided for @termsConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Я прочитал(а) и принимаю условия использования'**
  String get termsConfirm;

  /// No description provided for @termsAccept.
  ///
  /// In ru, this message translates to:
  /// **'Принять'**
  String get termsAccept;

  /// No description provided for @termsAcceptFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить принятие условий. Попробуйте ещё раз.'**
  String get termsAcceptFailed;

  /// No description provided for @reportUser.
  ///
  /// In ru, this message translates to:
  /// **'Пожаловаться'**
  String get reportUser;

  /// No description provided for @blockUser.
  ///
  /// In ru, this message translates to:
  /// **'Заблокировать пользователя'**
  String get blockUser;

  /// No description provided for @blockUserConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Заблокировать этого пользователя для будущих поездок и общения после поездки?'**
  String get blockUserConfirm;

  /// No description provided for @reportSent.
  ///
  /// In ru, this message translates to:
  /// **'Жалоба отправлена'**
  String get reportSent;

  /// No description provided for @userBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь заблокирован'**
  String get userBlocked;

  /// No description provided for @reportReasonAbuse.
  ///
  /// In ru, this message translates to:
  /// **'Оскорбления'**
  String get reportReasonAbuse;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In ru, this message translates to:
  /// **'Преследование'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonSpam.
  ///
  /// In ru, this message translates to:
  /// **'Спам'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonUnsafe.
  ///
  /// In ru, this message translates to:
  /// **'Опасное поведение'**
  String get reportReasonUnsafe;

  /// No description provided for @reportReasonInappropriate.
  ///
  /// In ru, this message translates to:
  /// **'Недопустимый контент'**
  String get reportReasonInappropriate;

  /// No description provided for @reportReasonOther.
  ///
  /// In ru, this message translates to:
  /// **'Другая причина'**
  String get reportReasonOther;

  /// No description provided for @aboutSupportTitle.
  ///
  /// In ru, this message translates to:
  /// **'О приложении и поддержка'**
  String get aboutSupportTitle;

  /// No description provided for @legalTerms.
  ///
  /// In ru, this message translates to:
  /// **'Условия использования'**
  String get legalTerms;

  /// No description provided for @legalTermsHint.
  ///
  /// In ru, this message translates to:
  /// **'Открыть актуальный полный текст'**
  String get legalTermsHint;

  /// No description provided for @legalPrivacy.
  ///
  /// In ru, this message translates to:
  /// **'Политика конфиденциальности'**
  String get legalPrivacy;

  /// No description provided for @legalPrivacyHint.
  ///
  /// In ru, this message translates to:
  /// **'Как MEKEN обрабатывает ваши данные'**
  String get legalPrivacyHint;

  /// No description provided for @legalAccountDeletion.
  ///
  /// In ru, this message translates to:
  /// **'Удаление аккаунта'**
  String get legalAccountDeletion;

  /// No description provided for @legalAccountDeletionHint.
  ///
  /// In ru, this message translates to:
  /// **'Инструкция и публичная страница удаления'**
  String get legalAccountDeletionHint;

  /// No description provided for @legalSupport.
  ///
  /// In ru, this message translates to:
  /// **'Поддержка'**
  String get legalSupport;

  /// No description provided for @legalSupportPending.
  ///
  /// In ru, this message translates to:
  /// **'Контакт будет опубликован до выпуска'**
  String get legalSupportPending;

  /// No description provided for @legalVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия приложения'**
  String get legalVersion;

  /// No description provided for @legalOpenFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть ссылку'**
  String get legalOpenFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'kk', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'kk':
      return AppLocalizationsKk();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
