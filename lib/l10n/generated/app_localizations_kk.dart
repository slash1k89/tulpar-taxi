// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kazakh (`kk`).
class AppLocalizationsKk extends AppLocalizations {
  AppLocalizationsKk([String locale = 'kk']) : super(locale);

  @override
  String get loginTitle => 'Кіру';

  @override
  String get verificationTitle => 'Нөмірді растау';

  @override
  String get profileTitle => 'Сізге қалай жүгінеміз?';

  @override
  String get phoneHint =>
      'Нөміріңізге қысқа қоңырау түседі.\nҚоңырау шалған нөмірдің соңғы 4 санын енгізіңіз.';

  @override
  String get codeHint => 'Қоңырау шалған нөмірдің соңғы 4 санын енгізіңіз';

  @override
  String get profileHint => 'Атыңыз профиліңізде көрсетіледі.';

  @override
  String get requestCode => 'Қоңырау арқылы код алу';

  @override
  String get confirm => 'Растау';

  @override
  String get continueLabel => 'Жалғастыру';

  @override
  String resendIn(int seconds) {
    return 'Қайта қоңырау шалу: $seconds сек. кейін';
  }

  @override
  String get resend => 'Қайта қоңырау шалу';

  @override
  String get phoneNumber => 'Телефон нөмірі';

  @override
  String get lastFourDigits => 'Соңғы 4 сан';

  @override
  String get nameLabel => 'Аты';

  @override
  String get invalidPhone => 'Телефон нөмірін дұрыс енгізіңіз.';

  @override
  String get invalidCode => 'Қоңырау шалған нөмірдің соңғы 4 санын енгізіңіз.';

  @override
  String get invalidName => 'Атыңыз 2–120 таңбадан тұруы керек.';

  @override
  String get resendCooldown => 'Қазір қайта қоңырау шалуға болмайды.';

  @override
  String get checkPhone => 'Телефон нөмірін тексеріңіз.';

  @override
  String get invalidVerification => 'Код қате немесе мерзімі өткен.';

  @override
  String get loginFailed => 'Жүйеге кіру мүмкін болмады. Қайталап көріңіз.';

  @override
  String get serverTimeout => 'Сервер жауап бермеді. Қайталап көріңіз.';

  @override
  String get chooseLanguage => 'Тілді таңдау';

  @override
  String get languageSetting => 'Тіл';

  @override
  String get registerTitle => 'Тіркелу';

  @override
  String get createAccount => 'Аккаунт ашу';

  @override
  String get registerButton => 'Тіркелу';

  @override
  String get authSignIn => 'Кіру';

  @override
  String get authForgotPassword => 'Құпиясөзді ұмыттыңыз ба?';

  @override
  String get authResetPasswordTitle => 'Құпиясөзді қалпына келтіру';

  @override
  String get authCreatePasswordTitle => 'Құпиясөз жасаңыз';

  @override
  String get authVerificationPhoneHint =>
      'Қоңырау арқылы растау үшін нөміріңізді енгізіңіз.';

  @override
  String get authPasswordTooShort => 'Құпиясөз кемінде 8 таңбадан тұруы керек.';

  @override
  String get authInvalidCredentials => 'Телефон нөмірі немесе құпиясөз қате.';

  @override
  String get authPasswordAlreadySet =>
      'Құпиясөз орнатылған. Қалпына келтіруді пайдаланыңыз.';

  @override
  String get authVerificationRequired => 'Нөмірді қайта растаңыз.';

  @override
  String get authBackToLogin => 'Кіруге оралу';

  @override
  String get passwordLabel => 'Құпиясөз';

  @override
  String get confirmPassword => 'Құпиясөзді қайталаңыз';

  @override
  String get enterName => 'Атыңызды енгізіңіз';

  @override
  String get nameTooLong => 'Атыңыз тым ұзын';

  @override
  String get enterPhone => 'Телефон нөмірін енгізіңіз';

  @override
  String get enterFullPhone => 'Телефон нөмірін толық енгізіңіз';

  @override
  String get enterPassword => 'Құпиясөзді енгізіңіз';

  @override
  String get shortPassword => 'Құпиясөз кемінде 6 таңбадан тұруы керек';

  @override
  String get passwordMismatch => 'Құпиясөздер сәйкес келмейді';

  @override
  String registrationSuccess(String phone) {
    return 'Пайдаланушы тіркелді: $phone';
  }

  @override
  String get pushOpen => 'Ашу';

  @override
  String get pushDriverApproachingTitle => 'Жүргізуші жақындап қалды';

  @override
  String get pushDriverApproachingBody =>
      'Шығуға дайындалыңыз — жүргізуші келіп қалды.';

  @override
  String get pushNewMessage => 'Чатта жаңа хабарлама бар';

  @override
  String get pushOrderAccepted => 'Жүргізуші сізге келе жатыр';

  @override
  String get pushDeliveryAccepted => 'Курьер сәлемдемені алуға келе жатыр';

  @override
  String get pushDriverArrived => 'Жүргізуші жетіп, сізді күтіп тұр!';

  @override
  String get pushDeliveryArrived => 'Курьер сәлемдемені алуға келді';

  @override
  String get pushTripStarted => 'Сапар басталды';

  @override
  String get pushDeliveryStarted => 'Сәлемдеме жолда';

  @override
  String get pushTripCompleted => 'Сапар аяқталды!';

  @override
  String get pushDeliveryCompleted => 'Жеткізу аяқталды';

  @override
  String get pushOrderCancelled => 'Тапсырыс тоқтатылды';

  @override
  String get pushNewDriverOrder => 'Жаңа тапсырыс';

  @override
  String get pushDriverHeading => 'Жүргізуші сізге қарай жолға шықты.';

  @override
  String get pushIntercityMatch => 'Сізге қолайлы қалааралық сапар табылды';

  @override
  String get pushIntercityCancelled => 'Жүргізуші сапарды тоқтатты';

  @override
  String get pushIntercityDeparted => 'Қалааралық сапар басталды';

  @override
  String get pushIntercityBooked => 'Қалааралық сапарға жаңа бронь';

  @override
  String get pushIntercityBookingCancelled =>
      'Қалааралық сапар броні тоқтатылды';

  @override
  String get serviceCity => 'Такси';

  @override
  String get serviceDelivery => 'Жеткізу';

  @override
  String get serviceIntercity => 'Қалааралық';

  @override
  String get driverCityOrders => 'Такси тапсырыстары';

  @override
  String get driverDeliveryOrders => 'Жеткізу тапсырыстары';

  @override
  String driverNewOrder(String service) {
    return 'Жаңа тапсырыс — $service';
  }

  @override
  String get statusSearchingDriver => 'Бос жүргізуші ізделуде...';

  @override
  String get statusSearchingCourier => 'Бос курьер ізделуде...';

  @override
  String get statusSearchingIntercity => 'Қалааралық жүргізуші ізделуде...';

  @override
  String get statusCourierComing => 'Курьер сәлемдемені алуға келе жатыр';

  @override
  String get statusDriverComing => 'Жүргізуші сізге келе жатыр';

  @override
  String get statusCourierArrived => 'Курьер сәлемдемені алуға келді';

  @override
  String get statusDriverArrived => 'Жүргізуші жетіп, сізді күтіп тұр!';

  @override
  String get statusIntercityDriverArrived => 'Жүргізуші келді';

  @override
  String get statusHandPackage => 'Сәлемдемені курьерге тапсырыңыз';

  @override
  String get statusGoToCar => 'Көлікке қарай шығыңыз';

  @override
  String get statusPackageOnWay => 'Сәлемдеме жолда';

  @override
  String get statusTripInProgress => 'Сапар жүріп жатыр';

  @override
  String get statusTripStarted => 'Сапар басталды';

  @override
  String get statusDeliveryCompleted => 'Жеткізу аяқталды';

  @override
  String get statusTripCompleted => 'Сапар аяқталды!';

  @override
  String get statusIntercityCompleted => 'Қалааралық сапар аяқталды';

  @override
  String get statusDriverFinishingPrevious =>
      'Жүргізуші алдыңғы сапарын аяқтап жатыр';

  @override
  String get cancelOrderTitle => 'Тапсырысты тоқтату';

  @override
  String get confirmCancelOrder =>
      'Тапсырысты тоқтатқыңыз келетініне сенімдісіз бе?';

  @override
  String get no => 'Жоқ';

  @override
  String get yesCancel => 'Иә, тоқтату';

  @override
  String offerAccepted(String driver, String price) {
    return '$driver: $price ₸ ұсынысы қабылданды.';
  }

  @override
  String get close => 'Жабу';

  @override
  String get cancelOrderFailed =>
      'Тапсырысты тоқтату мүмкін болмады. Байланысты тексеріп, қайта көріңіз.';

  @override
  String get yourOrder => 'Сіздің тапсырысыңыз';

  @override
  String get orderCancelled => 'Тапсырыс тоқтатылды';

  @override
  String get orderLoadFailed => 'Тапсырыс деректерін жүктеу мүмкін болмады';

  @override
  String get invalidOrderCoordinates =>
      'Тапсырыстың орналасу деректері дұрыс емес';

  @override
  String get cancelling => 'Тоқтатылуда...';

  @override
  String get cancelSearch => 'Іздеуді тоқтату';

  @override
  String get queuedOrderHint =>
      'Алдыңғы сапар аяқталған соң жүргізуші бірден сізге келеді.';

  @override
  String get cancelOrder => 'Тапсырысты тоқтату';

  @override
  String recipientAddress(String address) {
    return 'Алушының мекенжайы: $address';
  }

  @override
  String directionAddress(String address) {
    return 'Бағыт: $address';
  }

  @override
  String get addressUnknown => 'Мекенжай көрсетілмеген';

  @override
  String orderStatusUnknown(String status) {
    return 'Тапсырыс күйі: $status';
  }

  @override
  String get cancel => 'Тоқтату';

  @override
  String get courier => 'Курьер';

  @override
  String get driver => 'Жүргізуші';

  @override
  String get car => 'Көлік';

  @override
  String fromAddress(String address) {
    return 'Қайдан: $address';
  }

  @override
  String toAddress(String address) {
    return 'Қайда: $address';
  }

  @override
  String priceTenge(String price) {
    return 'Құны: $price ₸';
  }

  @override
  String get carLoading => 'Көлік деректері жүктелуде...';

  @override
  String get driverProfile => 'Жүргізуші профилі';

  @override
  String get chat => 'Чат';

  @override
  String get taxiAndDelivery => 'Такси және жеткізу';

  @override
  String get chatInvalidLength => 'Хабарлама 1–2000 таңбадан тұруы керек.';

  @override
  String get chatInvalidRequest => 'Сұрау деректері дұрыс емес.';

  @override
  String get chatForbidden => 'Бұл тапсырысқа кіруге рұқсатыңыз жоқ.';

  @override
  String get chatOrderNotFound => 'Тапсырыс табылмады.';

  @override
  String get chatSendFailed => 'Хабарламаны жіберу мүмкін болмады.';

  @override
  String chatRateLimited(int seconds) {
    return 'Хабарлама тым көп жіберілді. $seconds секундтан кейін қайталаңыз.';
  }

  @override
  String get retry => 'Қайталау';

  @override
  String get chatEmpty => 'Әзірге хабарлама жоқ. Бірінші болып жазыңыз!';

  @override
  String get chatMessageHint => 'Хабарлама...';

  @override
  String get mapDeliveryPriceRequired => 'Жеткізу бағасын көрсетіңіз.';

  @override
  String get mapTripPriceRequired => 'Сапар бағасын көрсетіңіз.';

  @override
  String get mapLocationSlow =>
      'Орналасқан жерді тез анықтау мүмкін болмады. Мекенжайды қолмен таңдаңыз.';

  @override
  String mapOutsideCity(String city) {
    return 'Сіз $city қаласынан тыс жердесіз.';
  }

  @override
  String mapChoosePointInCity(String city) {
    return '$city қаласындағы нүктені таңдаңыз.';
  }

  @override
  String get mapResolvingAddress => 'Мекенжай анықталуда...';

  @override
  String get mapChoosePointInKazakhstan =>
      'Қазақстан аумағындағы нүктені таңдаңыз.';

  @override
  String get mapPickupCity => 'Жөнелту қаласы';

  @override
  String get mapDestinationCity => 'Бару қаласы';

  @override
  String get mapChooseCity => 'Қаланы таңдаңыз';

  @override
  String get mapRouteFailed => 'Бағытты құру мүмкін болмады. Қайта көріңіз.';

  @override
  String get mapChooseFutureTime => 'Болашақ уақытты таңдаңыз.';

  @override
  String get mapChooseBothCities =>
      'Алдымен жөнелту және бару қалаларын таңдаңыз.';

  @override
  String get mapChooseRoutePoints =>
      'Картадан A және B нүктелерін белгілеңіз немесе тізімнен таңдаңыз.';

  @override
  String get mapPointA => 'A нүктесі';

  @override
  String get mapPointB => 'B нүктесі';

  @override
  String get mapServerTimeout => 'Сервер жауап бермеді. Қайта көріңіз.';

  @override
  String get mapStaleOrder =>
      'Ескі тапсырыс байланысы табылды. Ол автоматты түрде жойылған жоқ. Тексеру үшін әкімшіге хабарласыңыз.';

  @override
  String mapServiceInCity(String service, String city) {
    return '$service — $city';
  }

  @override
  String get mapExactPickupAddress => 'Жөнелтудің нақты мекенжайы';

  @override
  String get mapChooseAddress => 'Мекенжайды таңдаңыз';

  @override
  String get mapExactDeliveryAddress => 'Жеткізудің нақты мекенжайы';

  @override
  String get mapExactDestinationAddress => 'Баратын жердің нақты мекенжайы';

  @override
  String get mapRecipientApartment => 'Алушының пәтері (міндетті емес)';

  @override
  String get mapPackageDescription => 'Сәлемдеме сипаттамасы';

  @override
  String get mapPackageExample => 'Мысалы: құжаттар';

  @override
  String get mapRecipientName => 'Алушының аты';

  @override
  String get mapRecipientPhone => 'Алушының телефоны';

  @override
  String get mapPassengerCount => 'Жолаушылар саны';

  @override
  String get mapHasLuggage => 'Жүк бар';

  @override
  String get mapOptionalComment => 'Пікір (міндетті емес)';

  @override
  String get mapYourPrice => 'Сіздің бағаңыз (₸)';

  @override
  String get mapRequestDelivery => 'Жеткізуге тапсырыс беру';

  @override
  String get mapRequestIntercity => 'Қалааралық сапарға тапсырыс беру';

  @override
  String get mapRequestTaxi => 'Таксиге тапсырыс беру';

  @override
  String get orderErrorLogin => 'Аккаунтқа кіріп, қайта көріңіз.';

  @override
  String get orderErrorActive => 'Сізде белсенді тапсырыс бар.';

  @override
  String get orderErrorInvalid =>
      'Мекенжайларды, бағаны және бағыт нүктелерін тексеріңіз.';

  @override
  String get orderErrorDelivery =>
      'Сәлемдеме сипаттамасын, алушының аты мен телефонын толтырыңыз.';

  @override
  String get orderErrorIntercity =>
      'Қалааралық сапардың уақыты мен деректерін тексеріңіз.';

  @override
  String get orderErrorPermission => 'Тапсырыс жасауға рұқсат жоқ.';

  @override
  String get orderErrorUnavailable => 'Сервермен байланыс жоқ. Қайта көріңіз.';

  @override
  String get orderErrorUnknown =>
      'Тапсырыс жасау мүмкін болмады. Қайта көріңіз.';

  @override
  String get driverAcceptDelivery =>
      'Жеткізу қабылданды! Сәлемдемені алуға барыңыз.';

  @override
  String get driverAcceptIntercity =>
      'Қалааралық сапар қабылданды! Жолаушыға барыңыз.';

  @override
  String get driverAcceptCity => 'Тапсырыс қабылданды! Жолаушыға барыңыз.';

  @override
  String get driverAcceptFailed =>
      'Тапсырысты қабылдау мүмкін болмады. Қайта көріңіз.';

  @override
  String get driverProposePrice => 'Баға ұсыну';

  @override
  String get driverSendOffer => 'Жіберу';

  @override
  String get pickerResolvingAddress => 'Мекенжай анықталуда...';

  @override
  String get pickerAddressUnavailable =>
      'Мекенжай анықталмады. Координаттар сақталды.';

  @override
  String get pickerAddressTimeout =>
      'Мекенжай қызметі жауап бермеді. Координаттар сақталды.';

  @override
  String pickerCoordinate(String latitude, String longitude) {
    return 'Картадағы нүкте ($latitude, $longitude)';
  }

  @override
  String pickerChooseInCity(String city) {
    return '$city қаласының ішінен нүкте таңдаңыз.';
  }

  @override
  String get pickerCityCheckFailed =>
      'Қаланы тексеру мүмкін болмады. Желіні тексеріп, қайталаңыз.';

  @override
  String get pickerPointCheckFailed =>
      'Нүктені тексеру мүмкін болмады. Қайта көріңіз.';

  @override
  String get pickerEnableLocation => 'Телефонда геолокацияны қосыңыз.';

  @override
  String get pickerLocationDenied => 'Геолокацияға рұқсат берілмеді.';

  @override
  String get pickerLocationSettings =>
      'Қолданба баптауларында геолокацияға рұқсат беріңіз.';

  @override
  String get pickerLocationSlow =>
      'Орналасқан жер тез анықталмады. Нүктені қолмен таңдаңыз.';

  @override
  String get pickerLocationFailed =>
      'Орналасқан жер анықталмады. Нүктені қолмен таңдаңыз.';

  @override
  String get pickerNoLocation =>
      'Орналасқан жер алынбады. Нүктені қолмен таңдаңыз.';

  @override
  String get pickerCityCheckManual =>
      'Қаланы тексеру мүмкін болмады. Нүктені қолмен таңдаңыз не қайталаңыз.';

  @override
  String get pickerPickupTitle => 'Жөнелту нүктесі';

  @override
  String get pickerDestinationTitle => 'Баратын жер';

  @override
  String get pickerMyLocation => 'Менің орным';

  @override
  String get pickerChecking => 'Тексерілуде...';

  @override
  String get pickerChoosePoint => 'Осы нүктені таңдау';

  @override
  String get profileNotAuthenticated => 'Пайдаланушы жүйеге кірмеген';

  @override
  String get profileLoadFailed => 'Профиль жүктелмеді';

  @override
  String get profileSaved => 'Профиль сақталды';

  @override
  String get profileLegacyError =>
      'Профиль ескі форматта. Атыңызды толтырғаннан кейін қате қайталанса, Firebase жүйесіндегі uid, телефон, рөл және жасалған күнді тексеріңіз.';

  @override
  String profileSaveCodeError(String code) {
    return 'Профиль сақталмады: $code.';
  }

  @override
  String get profileSaveFailed => 'Профиль сақталмады.';

  @override
  String get profileDeleteTitle => 'Аккаунтты жою керек пе?';

  @override
  String get profileDeleteFinalTitle => 'Аккаунтты шынымен жою керек пе?';

  @override
  String get profileDeleteWarning =>
      'Бұл әрекетті қайтару мүмкін емес. Алдымен белсенді тапсырыстар мен сапарларды аяқтаңыз немесе тоқтатыңыз.';

  @override
  String get profileDeleteFinalWarning =>
      'Жалғастырсаңыз, аккаунт пен жеке деректерді қалпына келтіру мүмкін болмайды.';

  @override
  String get profileYesDelete => 'Иә, жою';

  @override
  String get profileDeleteCallRequired =>
      'Аккаунтты жою үшін қоңырау арқылы қайта растау қажет.';

  @override
  String get profileDeleted => 'Аккаунт жойылды.';

  @override
  String get profileDeletionPending =>
      'Жою сұрауы қабылданды. Бұл біраз уақыт алуы мүмкін.';

  @override
  String get profileDeleteFailed => 'Аккаунт жойылмады.';

  @override
  String get profileSettingsTitle => 'Профиль және баптаулар';

  @override
  String get profileName => 'Аты';

  @override
  String get profileEnterName => 'Атыңызды енгізіңіз';

  @override
  String get profileNameTooLong => 'Аты тым ұзын';

  @override
  String get profilePhone => 'Телефон нөмірі';

  @override
  String get profilePhoneReadonly => 'Телефон нөмірін өзгерту мүмкін емес';

  @override
  String get profileCar => 'Автокөліктің маркасы мен моделі';

  @override
  String get profileTheme => 'Тақырып';

  @override
  String get profileThemeSystem => 'Жүйедегідей';

  @override
  String get profileThemeLight => 'Ашық';

  @override
  String get profileThemeDark => 'Қараңғы';

  @override
  String get profileVoice => 'Дауыстық нұсқаулар';

  @override
  String get profileVoiceHint => 'Навигация кезінде бұрылыстарды дауыстап айту';

  @override
  String get profileSave => 'Деректерді сақтау';

  @override
  String get profilePasswordTitle => 'Құпиясөзді растаңыз';

  @override
  String get profileCurrentPassword => 'Ағымдағы құпиясөз';

  @override
  String get profileEnterPassword => 'Құпиясөзді енгізіңіз';

  @override
  String unreadMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count оқылмаған хабарлама',
    );
    return '$_temp0';
  }

  @override
  String get agreementSaveFailed => 'Келісім сақталмады. Қайта көріңіз.';

  @override
  String get agreementRulesTitle => 'Жүргізушінің жұмыс ережелері';

  @override
  String agreementVersion(String version) {
    return 'Келісім нұсқасы $version';
  }

  @override
  String get agreementBody =>
      'Жүргізуші режиміне өтіп, мыналарды растаймын:\n\n• автокөлік жүргізуге құқығым бар және техникалық жарамды көлік қолданамын;\n\n• жол қозғалысы ережелері мен қауіпсіздік талаптарын сақтаймын;\n\n• көлікті таза ұстаймын және жолаушылармен сыпайы сөйлесемін;\n\n• қауіпсіз көлік жүргізуге кедергі келтіретін күйде желіге шықпаймын;\n\n• көлік туралы шынайы дерек беремін және аккаунтты басқаға бермеймін;\n\n• жолаушының деректерін тек тапсырысты орындау үшін қолданамын.';

  @override
  String get agreementConfirm => 'Ережелерді оқыдым және келісімді қабылдаймын';

  @override
  String get agreementAcceptContinue => 'Қабылдау және жалғастыру';

  @override
  String get onboardingLoginRequired =>
      'Жүргізуші режимін қосу үшін аккаунтқа кіріңіз.';

  @override
  String get onboardingServerTimeout =>
      'Сервер жауап бермеді. Интернетті тексеріп, қайталаңыз.';

  @override
  String get onboardingLoadFailed => 'Жүргізуші профилі жүктелмеді.';

  @override
  String get onboardingActivated => 'Жүргізуші профилі іске қосылды';

  @override
  String get onboardingRetryTimeout => 'Сервер жауап бермеді. Қайта көріңіз.';

  @override
  String get onboardingSubmitFailed => 'Жүргізуші өтінімі жіберілмеді.';

  @override
  String get onboardingPermissionDenied =>
      'Жүргізуші профилін өзгертуге құқық жеткіліксіз.';

  @override
  String get onboardingUnavailable =>
      'Қызмет уақытша қолжетімсіз. Интернетті тексеріңіз.';

  @override
  String onboardingFirebaseError(String code) {
    return 'Firebase қатесі: $code. Қайта көріңіз.';
  }

  @override
  String get onboardingPendingTitle => 'Жүргізуші өтінімі тексеруге жіберілді.';

  @override
  String get onboardingPendingBody =>
      'Мақұлданғаннан кейін жүргізуші режимі автоматты түрде ашылады. Келісім мен көлік деректерін қайта толтыру қажет емес.';

  @override
  String get onboardingCheckStatus => 'Күйін тексеру';

  @override
  String get onboardingSuspendedTitle =>
      'Жүргізушіге қолжетімділік тоқтатылды.';

  @override
  String get onboardingSuspendedBody =>
      'Қазір тапсырыс қабылдай алмайсыз. Себебін білу үшін MEKEN әкімшісіне хабарласыңыз.';

  @override
  String get onboardingCheckAgain => 'Қайта тексеру';

  @override
  String get onboardingDriverMode => 'Жүргізуші режимі';

  @override
  String get onboardingVehicleTitle => 'Жүргізушінің көлігі';

  @override
  String get onboardingFillVehicle => 'Көлік деректерін толтырыңыз';

  @override
  String get onboardingVehicleHint =>
      'Жіберілген соң өтінім тексеріледі. Бұл деректерді жолаушы тапсырыс қабылданғаннан кейін ғана көреді.';

  @override
  String get onboardingCarModel => 'Маркасы мен моделі';

  @override
  String get onboardingCarModelRequired =>
      'Көліктің маркасы мен моделін көрсетіңіз';

  @override
  String get onboardingCarColor => 'Кузов түсі';

  @override
  String get onboardingCarColorRequired => 'Көліктің түсін көрсетіңіз';

  @override
  String get onboardingCarNumber => 'Мемлекеттік нөмір';

  @override
  String get onboardingCarNumberRequired => 'Мемлекеттік нөмірді көрсетіңіз';

  @override
  String get onboardingSubmit => 'Өтінімді тексеруге жіберу';

  @override
  String get drawerEnabled => 'Қосулы';

  @override
  String get drawerDisabled => 'Өшірулі';

  @override
  String get drawerHistory => 'Тапсырыстар тарихы';

  @override
  String get drawerSignOut => 'Шығу';

  @override
  String deliveryPackage(String description) {
    return 'Сәлемдеме: $description';
  }

  @override
  String deliveryRecipient(String name) {
    return 'Алушы: $name';
  }

  @override
  String deliveryPhone(String phone) {
    return 'Телефон: $phone';
  }

  @override
  String get deliveryCallRecipient => 'Алушыға қоңырау шалу';

  @override
  String deliveryApartment(String apartment) {
    return 'Пәтер: $apartment';
  }

  @override
  String get deliveryDialerFailed => 'Қоңырау шалу қолданбасы ашылмады.';

  @override
  String intercityKazakhstanTime(String time) {
    return '$time · Қазақстан уақыты';
  }

  @override
  String intercityPassengers(int count) {
    return 'Жолаушылар: $count';
  }

  @override
  String get intercityHasLuggage => 'Жүк бар';

  @override
  String intercityComment(String comment) {
    return 'Пікір: $comment';
  }

  @override
  String intercityPrice(int price) {
    return 'Баға: $price ₸';
  }

  @override
  String get intercitySearchCityHint => 'Қала немесе елді мекен';

  @override
  String get intercityStreetHouseHint => 'Көше мен үй';

  @override
  String get intercityChooseOnMap => 'Картадан таңдау';

  @override
  String get profileWrongPassword => 'Құпиясөз қате.';

  @override
  String get profileTooManyAttempts =>
      'Тым көп әрекет жасалды. Кейінірек қайталаңыз.';

  @override
  String get profileNetworkError => 'Желіге қосылу жоқ. Қайта көріңіз.';

  @override
  String get profileUserDisabled => 'Бұл аккаунт өшірілген.';

  @override
  String get profileUserNotFound => 'Ағымдағы аккаунт расталмады.';

  @override
  String get profileRecentLoginRequired => 'Аккаунтқа қайта кіру қажет.';

  @override
  String get profileReauthFailed => 'Құпиясөз расталмады.';

  @override
  String get profileDeletionUnknown =>
      'Жою нәтижесін растау мүмкін болмады. Аккаунт күйін кейінірек тексеріңіз.';

  @override
  String get intercityOrderCar => 'Көлікке тапсырыс беру';

  @override
  String get intercityOrderCarHint => 'Қажетті мекенжайға дейін толық көлік';

  @override
  String get intercityFindRide => 'Сапарлас табу';

  @override
  String get intercityFindRideHint => 'Жүргізушінің сапарынан орын броньдау';

  @override
  String get intercityMyBookings => 'Менің броньдарым';

  @override
  String get intercityLookingForRide => 'Сапарлас іздеймін';

  @override
  String get intercityChooseCities =>
      'Жөнелту және баратын қалаларды таңдаңыз.';

  @override
  String get intercityDifferentCities =>
      'Жөнелту және баратын қалалар әртүрлі болуы керек.';

  @override
  String get intercityDatePast => 'Сапар күні өткен күн болмауы керек.';

  @override
  String get intercitySeatsRange => '1-ден 7-ге дейін орын таңдаңыз.';

  @override
  String get intercityFrom => 'Қайдан';

  @override
  String get intercityTo => 'Қайда';

  @override
  String get intercityTravelDate => 'Сапар күні';

  @override
  String get intercityFindTrips => 'Сапарларды табу';

  @override
  String get intercitySeatCount => 'Орын саны';

  @override
  String get intercityDecrease => 'Азайту';

  @override
  String get intercityIncrease => 'Көбейту';

  @override
  String intercitySeatSemantics(int count) {
    return 'Орын саны: $count';
  }

  @override
  String get intercityMatchingTrips => 'Сәйкес сапарлар';

  @override
  String get intercityTripsLoadFailed => 'Сапарлар жүктелмеді';

  @override
  String get intercityNoTrips => 'Әзірге сәйкес сапар жоқ';

  @override
  String get intercityLeaveRequest => 'Өтінім қалдыру';

  @override
  String intercityAvailableSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Бос орын: $count',
    );
    return '$_temp0';
  }

  @override
  String intercityPerSeat(String price) {
    return '$price / орын';
  }

  @override
  String get intercityDetails => 'Толығырақ';

  @override
  String get datePreviousMonth => 'Алдыңғы ай';

  @override
  String get dateNextMonth => 'Келесі ай';

  @override
  String get dateDone => 'Дайын';

  @override
  String get historyNoAddress => 'Мекенжай көрсетілмеген';

  @override
  String get historyDriverRole => 'Мен жүргізушімін';

  @override
  String get historyPassengerRole => 'Мен жолаушымын';

  @override
  String get historyTitle => 'Сапарлар тарихы';

  @override
  String get historyLoadFailed => 'Сапарлар тарихы жүктелмеді.';

  @override
  String get historyEmpty => 'Әзірге аяқталған сапар жоқ';

  @override
  String get historyCompleted => 'Аяқталды';

  @override
  String get historyCancelled => 'Тоқтатылды';

  @override
  String historyPrice(String price) {
    return '$price ₸';
  }

  @override
  String get driverMapActionFailed => 'Тапсырыс жаңартылмады. Қайта көріңіз.';

  @override
  String get driverMapRerouteFailed => 'Бағытты қайта құру мүмкін болмады';

  @override
  String get driverMapCustomer => 'тапсырыс берушіні';

  @override
  String get driverMapNextLoadFailed =>
      'Келесі тапсырыс қабылданды. Деректер жүктелмеді.';

  @override
  String get driverMapNextAccepted => 'Келесі тапсырыс қабылданды';

  @override
  String get driverMapNextUnavailable => 'Тапсырыс енді қолжетімсіз';

  @override
  String get driverMapOwnPrice => 'Өз бағам';

  @override
  String get driverMapPriceLabel => 'Баға, ₸';

  @override
  String get driverMapOfferSent => 'Ұсыныс жолаушыға жіберілді';

  @override
  String get driverMapArrivedAction => 'Мен келдім';

  @override
  String get driverMapPackageReceived => 'Сәлемдеме алынды';

  @override
  String get driverMapStartTrip => 'Сапарды бастау';

  @override
  String get driverMapCompleteDelivery => 'Жеткізуді аяқтау';

  @override
  String get driverMapCompleteTrip => 'Сапарды аяқтау';

  @override
  String get driverMapDeliveryTitle => 'Жеткізу орындалуда';

  @override
  String get driverMapIntercityTitle => 'Қалааралық сапар';

  @override
  String get driverMapCityTitle => 'Тапсырыс орындалуда';

  @override
  String driverMapCollectPackage(String address) {
    return 'Сәлемдемені алыңыз: $address';
  }

  @override
  String driverMapClientWaiting(String address) {
    return 'Клиент күтуде: $address';
  }

  @override
  String get orderOfferAcceptFailed => 'Ұсыныс қабылданбады. Қайта көріңіз.';

  @override
  String get trackingStopped => 'Геолокацияны бақылау тоқтатылды.';

  @override
  String get trackingSignIn => 'Жүргізуші аккаунтына кіріңіз.';

  @override
  String get trackingEnableServices => 'Геолокация қызметтерін қосыңыз.';

  @override
  String get trackingAllowLocation => 'Геолокацияға рұқсат беріңіз.';

  @override
  String get trackingAllowInSettings =>
      'Қолданба баптауларында геолокацияға рұқсат беріңіз.';

  @override
  String get trackingPositionFailed =>
      'Ағымдағы орынды алу немесе жіберу мүмкін болмады.';

  @override
  String get driverChangeOffer => 'Ұсынысты өзгерту';

  @override
  String driverPassengerPrice(int price) {
    return 'Жолаушы бағасы: $price ₸';
  }

  @override
  String get driverYourPrice => 'Сіздің бағаңыз, ₸';

  @override
  String get driverEnterWholeAmount => 'Бүтін соманы енгізіңіз.';

  @override
  String get driverOfferAbovePrice =>
      'Ұсыныс жолаушы бағасынан жоғары болуы керек.';

  @override
  String get driverOfferTooHigh =>
      'Ұсыныс бағасы 1 000 000 ₸-ден аспауы керек.';

  @override
  String driverOfferSent(int price) {
    return '$price ₸ ұсынысы жолаушыға жіберілді.';
  }

  @override
  String get driverOfferFailed =>
      'Ұсынысты жіберу мүмкін болмады. Қайта көріңіз.';

  @override
  String get driverNotAuthenticated => 'Жүргізуші жүйеге кірмеген';

  @override
  String get driverOnline => 'Желіде';

  @override
  String get driverActiveCheckFailed =>
      'Ағымдағы тапсырысты тексеру мүмкін болмады. Тексеру автоматты түрде қайталанады.';

  @override
  String get driverNoOrders => 'Әзірге қолжетімді тапсырыс жоқ';

  @override
  String get passenger => 'Жолаушы';

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
    return 'Сіз $price ₸ ұсындыңыз';
  }

  @override
  String get driverChangePrice => 'Бағаны өзгерту';

  @override
  String driverAcceptForPrice(int price) {
    return '$price ₸-ге қабылдау';
  }

  @override
  String get driverOrdersForbidden =>
      'Тапсырыстарға рұқсат жоқ. Жүргізуші профилі мақұлдануы керек.';

  @override
  String get driverOrdersConfigFailed =>
      'Тапсырыстарды алу қолжетімсіз. Сервис баптауларын тексеріңіз.';

  @override
  String get driverOrdersTimeout =>
      'Сервер уақытында жауап бермеді. Тексеру автоматты түрде қайталанады.';

  @override
  String get driverOrdersLoadFailed =>
      'Қолжетімді тапсырыстарды жаңарту мүмкін болмады. Тексеру автоматты түрде қайталанады.';

  @override
  String get bookingCancelTitle => 'Броньды болдырмау керек пе?';

  @override
  String get bookingBack => 'Артқа';

  @override
  String get bookingCancelExplanation =>
      'Брондалған орындар қайтадан қолжетімді болады.';

  @override
  String get bookingCancel => 'Броньды болдырмау';

  @override
  String get bookingCancelFailed =>
      'Броньды болдырмау мүмкін болмады. Қайталап көріңіз.';

  @override
  String get bookingLoadFailed => 'Броньдарды жүктеу мүмкін болмады';

  @override
  String get bookingEmpty => 'Әзірге броньдарыңыз жоқ';

  @override
  String bookingSeatsAndPrice(int count, String price) {
    return '$count орын · $price';
  }

  @override
  String bookingPickup(String address) {
    return 'Міну орны: $address';
  }

  @override
  String bookingComment(String comment) {
    return 'Жүргізушіге түсініктеме: $comment';
  }

  @override
  String bookingDriver(String name) {
    return 'Жүргізуші: $name';
  }

  @override
  String bookingPhone(String phone) {
    return 'Телефон: $phone';
  }

  @override
  String get bookingUpcoming => 'Алдағы сапарлар';

  @override
  String get bookingCancelled => 'Болдырылмағандар';

  @override
  String get bookingCompleted => 'Аяқталғандар';

  @override
  String get bookingOther => 'Басқалары';

  @override
  String get profileActiveOrder =>
      'Алдымен ағымдағы тапсырысты аяқтаңыз немесе болдырмаңыз.';

  @override
  String get profileActiveDriverOrder =>
      'Алдымен жүргізуші ретіндегі белсенді тапсырысты аяқтаңыз.';

  @override
  String get profileActiveRide =>
      'Алдымен ортақ сапарды аяқтаңыз немесе болдырмаңыз.';

  @override
  String get profileActiveBooking =>
      'Алдымен броньды аяқтаңыз немесе болдырмаңыз.';

  @override
  String get profileActiveRideRequest =>
      'Алдымен белсенді ортақ сапар сұрауын болдырмаңыз.';

  @override
  String get profileDeletionManualReview =>
      'Есептік жазбаны жою үшін қолдау қызметінің тексеруі қажет.';

  @override
  String get driverIntercityOrders => 'Жолаушылар тапсырыстары';

  @override
  String get driverIntercityOrdersHint => 'Қалааралық жеке тапсырыстар';

  @override
  String get driverIntercityMyRides => 'Менің сапарларым';

  @override
  String get driverIntercityMyRidesHint =>
      'Жарияланған ортақ сапарлар мен броньдар';

  @override
  String get driverIntercityCreateRide => 'Сапар жасау';

  @override
  String get driverIntercityCreateHint => 'Сапарластарға орын жариялау';

  @override
  String get intercityPickupPoint => 'Міну орны';

  @override
  String get driverRidesEmpty => 'Сіз әлі сапар жариялаған жоқсыз';

  @override
  String driverRideTotalSeats(int count) {
    return 'Барлығы $count орын';
  }

  @override
  String get driverRideScheduled => 'Жоспарланған';

  @override
  String get driverRideDeparted => 'Жолда';

  @override
  String get driverRideCompleted => 'Аяқталған';

  @override
  String get driverRideCancelled => 'Болдырылмаған';

  @override
  String get driverRideUnknown => 'Белгісіз мәртебе';

  @override
  String get driverRideGroupDeparted => 'Жолда';

  @override
  String get publicDriverLoadFailed =>
      'Жүргізуші профилін жүктеу мүмкін болмады';

  @override
  String get publicDriverNoRatings => 'Бағалар жоқ';

  @override
  String publicDriverRatingCount(int count) {
    return '$count баға';
  }

  @override
  String get publicDriverReviews => 'Пікірлер';

  @override
  String get publicDriverNoReviews => 'Әзірге пікірлер жоқ';

  @override
  String get ratingTitleDriver => 'Жүргізушіні бағалаңыз';

  @override
  String get ratingCourierObject => 'Курьерді';

  @override
  String get ratingTitlePassenger => 'Жолаушыны бағалаңыз';

  @override
  String ratingTitleName(String name) {
    return '$name бағалаңыз';
  }

  @override
  String ratingStarTooltip(int score) {
    return '5-тен $score';
  }

  @override
  String get ratingReviewHint => 'Пікір жазыңыз (міндетті емес)';

  @override
  String get ratingCancel => 'Болдырмау';

  @override
  String get ratingSubmit => 'Жіберу';

  @override
  String get ratingInvalidRequest => 'Сұрау деректері қате.';

  @override
  String get ratingForbidden => 'Баға беруге рұқсатыңыз жоқ.';

  @override
  String get ratingOrderMissing => 'Бағаланатын тапсырыс табылмады.';

  @override
  String get ratingAlreadySent => 'Бұл тапсырыс бойынша баға берілген.';

  @override
  String get ratingNotCompleted => 'Тек аяқталған тапсырысты бағалауға болады.';

  @override
  String get ratingInvalidScore =>
      '1-ден 5-ке дейін баға беріңіз. Пікір 500 таңбадан аспауы керек.';

  @override
  String get ratingFailed => 'Бағаны жіберу мүмкін болмады. Қайталап көріңіз.';

  @override
  String get mapSelectedPoint => 'Таңдалған нүкте';

  @override
  String get mapPickupMarker => 'Алу орны';

  @override
  String get mapDestinationMarker => 'Баратын орын';

  @override
  String get mapUserMarker => 'Сіздің орналасқан жеріңіз';

  @override
  String get mapCourierMarker => 'Картадағы курьер';

  @override
  String get mapVehicleMarker => 'Картадағы көлік';

  @override
  String get intercityPickupPrompt => 'Сізді қай жерден алып кету керек?';

  @override
  String get requestSelectOriginFirst => 'Алдымен жөнелетін қаланы таңдаңыз.';

  @override
  String get requestFutureDate => 'Сұрауды тек болашақ күнге қалдыруға болады.';

  @override
  String get requestCommentTooLong => 'Түсініктеме 1000 таңбадан аспауы керек.';

  @override
  String get requestSelectPickup => 'Міну орнын таңдаңыз.';

  @override
  String get requestSaved => 'Сұрау сақталды';

  @override
  String get requestDuplicate => 'Мұндай белсенді сұрау бұрыннан бар.';

  @override
  String get requestSaveFailed =>
      'Сұрауды сақтау мүмкін болмады. Қайталап көріңіз.';

  @override
  String get requestCancelTitle => 'Сұрауды болдырмау керек пе?';

  @override
  String get requestCancelFailed =>
      'Сұрауды болдырмау мүмкін болмады. Қайталап көріңіз.';

  @override
  String get requestNotifyHint => 'Сәйкес сапар пайда болғанда хабарлаймыз.';

  @override
  String get requestCommentLabel => 'Жүргізушіге түсініктеме (міндетті емес)';

  @override
  String get requestCommentHint => 'Мысалы, негізгі кіреберіске келіңіз';

  @override
  String get requestMyRequests => 'Менің сұрауларым';

  @override
  String get requestLoadFailed => 'Сұрауларды жүктеу мүмкін болмады';

  @override
  String get requestEmpty => 'Әзірге белсенді сұраулар жоқ';

  @override
  String requestDateSeats(String date, int count) {
    return '$date · $count орын';
  }

  @override
  String get requestMatchedRides => 'Табылған сапарлар:';

  @override
  String requestMatchedRide(int number) {
    return 'Сапар $number';
  }

  @override
  String get requestCancel => 'Сұрауды болдырмау';

  @override
  String get requestActive => 'Белсенді';

  @override
  String get requestCancelled => 'Болдырылмаған';

  @override
  String get requestExpired => 'Мерзімі өткен';

  @override
  String get recoveryCheckFailed =>
      'Профильді тексеру мүмкін болмады. Интернетті тексеріп, қайталаңыз.';

  @override
  String get recoveryNameLimit => 'Атыңызды 80 таңбадан асырмай енгізіңіз.';

  @override
  String get recoveryTitle => 'Профильді қалпына келтіру';

  @override
  String get recoveryLegacyTitle => 'Профиль ескі форматта';

  @override
  String get recoveryEnterName => 'Атыңызды енгізіңіз';

  @override
  String get recoveryIncomplete => 'Тексеруді аяқтау мүмкін болмады';

  @override
  String get recoveryAdminBody =>
      'Қорғалған өрістерді телефоннан қауіпсіз қалпына келтіру мүмкін емес. Бұл профильге әкімшілік көшіру қажет.';

  @override
  String get recoveryAdminFields => 'Әкімшілік қалпына келтіру қажет:';

  @override
  String get recoveryLegacyWarning =>
      'Ескі isDriver, driverActiveUntil және автомобиль деректері табылды, бірақ олар жүргізуші құқығын беру үшін пайдаланылмайды.';

  @override
  String get recoveryNameBody =>
      'Атыңыз профильде де, Firebase Auth-та да жоқ. Атыңызды енгізіңіз — басқа қорғалған өрістер өзгермейді.';

  @override
  String get recoverySaveContinue => 'Сақтап, жалғастыру';

  @override
  String get recoveryCheckAgain => 'Қайта тексеру';

  @override
  String get recoverySignOut => 'Аккаунттан шығу';

  @override
  String get recoveryFieldUid => 'аккаунт идентификаторы (uid)';

  @override
  String get recoveryFieldName => 'аты';

  @override
  String get recoveryFieldPhone => 'расталған телефон';

  @override
  String get recoveryFieldRole => 'негізгі passenger рөлі';

  @override
  String get recoveryFieldRating => 'бастапқы рейтинг 5.0';

  @override
  String get recoveryFieldCreatedAt => 'Firebase Auth-тағы тіркелген күн';

  @override
  String get driverRideUpdated => 'Сапар жаңартылды';

  @override
  String get driverRidePublished => 'Сапар жарияланды';

  @override
  String get driverRideEditTitle => 'Сапарды өзгерту';

  @override
  String get driverRideCreateTitle => 'Сапар құру';

  @override
  String get driverRideProtected =>
      'Брондаудан кейін бағытты, уақытты және орын санын өзгертуге болмайды.';

  @override
  String get driverRideRoute => 'Бағыт';

  @override
  String get driverRideDate => 'Күні';

  @override
  String get driverRideTime => 'Уақыты';

  @override
  String get driverRidePricePerSeat => 'Орын бағасы';

  @override
  String get driverRidePriceNotice =>
      'Жаңа баға бұрын жасалған броньдардың сомасын өзгертпейді.';

  @override
  String get driverRideLuggageAllowed => 'Жүкке рұқсат етілген';

  @override
  String get driverRideNoLuggage => 'Жүксіз';

  @override
  String get driverRideComment => 'Пікір';

  @override
  String get driverRidePublish => 'Сапарды жариялау';

  @override
  String get driverRideChooseCities => 'Шығу және бару қалаларын таңдаңыз.';

  @override
  String get driverRideDifferentCities =>
      'Шығу және бару қалалары әртүрлі болуы керек.';

  @override
  String get driverRideFutureTime => 'Болашақ күн мен уақытты таңдаңыз.';

  @override
  String get driverRideSeatsRange => '1-ден 7-ге дейін орын ұсынуға болады.';

  @override
  String get driverRideInvalidPrice => 'Орынның дұрыс бағасын енгізіңіз.';

  @override
  String get driverRideCommentLong => 'Пікір тым ұзын.';

  @override
  String get driverRideInvalidData => 'Сапар деректерін тексеріңіз.';

  @override
  String get driverRideLogin => 'Аккаунтқа кіріп, қайталаңыз.';

  @override
  String get driverRideAccess => 'Жүргізушіге кіру құқығы белсенді емес.';

  @override
  String get driverRideMissing => 'Сапар табылмады.';

  @override
  String get driverRideChanged => 'Сапар өзгерді. Деректерді жаңартыңыз.';

  @override
  String get driverRideSaveFailed => 'Сапарды сақтау мүмкін болмады.';

  @override
  String get driverRideServerTimeout =>
      'Сервер жауап бермеді. Кейінірек қайталаңыз.';

  @override
  String get bookingPickupCityFailed =>
      'Мінетін қаланы анықтау мүмкін болмады.';

  @override
  String get bookingSelectPickup => 'Мінетін орынды таңдаңыз.';

  @override
  String get bookingCommentLimit => 'Пікір 1000 таңбадан аспауы керек.';

  @override
  String get bookingConfirmTitle => 'Брондауды растау керек пе?';

  @override
  String get bookingBook => 'Брондау';

  @override
  String get bookingBooked => 'Орын брондалды';

  @override
  String get bookingSavedBody => 'Бронь «Менің броньдарым» бөлімінде сақталды.';

  @override
  String get bookingStay => 'Осында қалу';

  @override
  String get bookingRide => 'Сапар';

  @override
  String get bookingLoadRideFailed => 'Сапарды жүктеу мүмкін болмады';

  @override
  String bookingTotal(String price) {
    return 'Барлығы: $price';
  }

  @override
  String bookingBookSeats(int count) {
    return '$count орынды брондау';
  }

  @override
  String bookingConfirmSummary(String seats, String price, String address) {
    return '$seats · $price\n$address';
  }

  @override
  String get bookingRideChanged => 'Сапар өзгерді немесе бос орын жеткіліксіз.';

  @override
  String get bookingLogin => 'Аккаунтқа кіріп, қайталаңыз.';

  @override
  String get bookingServerTimeout => 'Сервер жауап бермеді. Қайталаңыз.';

  @override
  String get bookingFailed => 'Орынды брондау мүмкін болмады. Қайталаңыз.';

  @override
  String get driverRideDetailsTitle => 'Сапар мәліметтері';

  @override
  String get driverRideStatusLabel => 'Күйі';

  @override
  String get driverRideDeparture => 'Аттану';

  @override
  String get driverRideTotalSeatsLabel => 'Барлық орын';

  @override
  String get driverRideAvailableSeatsLabel => 'Бос орын';

  @override
  String get driverRideBookedSeatsLabel => 'Брондалған орын';

  @override
  String get driverRideLuggage => 'Жүк';

  @override
  String get driverRideYes => 'Рұқсат етілген';

  @override
  String get driverRideNo => 'Жоқ';

  @override
  String get driverRideVehicle => 'Автомобиль';

  @override
  String get driverRidePassengers => 'Жолаушылар';

  @override
  String get driverRideNoBookings => 'Әзірге ешкім орын брондаған жоқ';

  @override
  String get driverRideCancelTrip => 'Сапарды тоқтату';

  @override
  String get driverRideStartTrip => 'Сапарды бастау';

  @override
  String get driverRideFinishTrip => 'Сапарды аяқтау';

  @override
  String get driverRideBookingConfirmed => 'Расталды';

  @override
  String get driverRideBookingCancelled => 'Тоқтатылды';

  @override
  String get driverRideBookingCompleted => 'Аяқталды';

  @override
  String get driverRideBookingUnknown => 'Күйі белгісіз';

  @override
  String get driverRideCancelTitle => 'Сапарды тоқтату керек пе?';

  @override
  String get driverRideDepartTitle => 'Сапарды бастау керек пе?';

  @override
  String get driverRideCompleteTitle => 'Сапарды аяқтау керек пе?';

  @override
  String get driverRideCancelAction => 'Тоқтату';

  @override
  String get driverRideDepartAction => 'Бастау';

  @override
  String get driverRideCompleteAction => 'Аяқтау';

  @override
  String get driverRideCancelBookingsWarning =>
      'Жолаушылардың барлық броньдары тоқтатылады.';

  @override
  String get driverRideCancelNoBookings =>
      'Сапар енді жолаушыларға қолжетімді болмайды.';

  @override
  String get driverRideDepartWarning =>
      'Аттанғаннан кейін жаңа броньдар мен жолаушының броньды тоқтатуы мүмкін болмайды.';

  @override
  String get driverRideCompleteWarning => 'Сапардың аяқталғанын растаңыз.';

  @override
  String driverRideBookingSummary(int count, String price) {
    return '$count орын · $price';
  }

  @override
  String driverRidePassengerName(String name) {
    return 'Жолаушы: $name';
  }

  @override
  String driverRidePickupComment(String comment) {
    return 'Жолаушының пікірі: $comment';
  }

  @override
  String get driverRideShowMap => 'Картадан көрсету';

  @override
  String get navigationGpsRequired => 'GPS-ке қол жеткізу рұқсаты қажет';

  @override
  String get navigationRecalculating => 'Бағыт қайта есептелуде...';

  @override
  String get navigationRecalculateFailed =>
      'Бағытты қайта есептеу мүмкін болмады.';

  @override
  String get navigationTitle => 'Тапсырыс бағыты';

  @override
  String get navigationMapPlaceholder => 'Карта осы жерде көрсетіледі';

  @override
  String get timePickerChoose => 'Уақытты таңдаңыз';

  @override
  String get timePickerHours => 'Сағат';

  @override
  String get timePickerMinutes => 'Минут';

  @override
  String get timePickerDone => 'Дайын';

  @override
  String get nextOrderNearby => 'Келесі тапсырыс жақын';

  @override
  String nextOrderDistance(int meters) {
    return 'Алу орнына дейін $meters м';
  }

  @override
  String get nextOrderOwnPrice => 'Өз бағам';

  @override
  String get nextOrderAccept => 'Қабылдау';

  @override
  String get registerUnexpectedError =>
      'Тіркелу мүмкін болмады. Қайталап көріңіз.';

  @override
  String get driverOrderUpdateFailed =>
      'Тапсырыс күйін жаңарту мүмкін болмады. Қайталап көріңіз.';

  @override
  String get driverOrderHeading => 'Клиентке барамыз';

  @override
  String get driverOrderWaiting => 'Клиентті күту';

  @override
  String get driverOrderInProgress => 'Сапар жүріп жатыр';

  @override
  String get driverOrderAtPickup => 'Орнында';

  @override
  String get driverOrderStart => 'Сапарды бастау';

  @override
  String get driverOrderFinish => 'Сапарды аяқтау';

  @override
  String get driverOrderCost => 'Құны:';

  @override
  String bookingSeats(int count) {
    return '$count орын';
  }

  @override
  String get navContinueToPoint => 'Нүктеге қарай жүре беріңіз';

  @override
  String get navArrived => 'Сіз келдіңіз';

  @override
  String get navDepart => 'Қозғалысты бастаңыз';

  @override
  String get navExitRoundabout => 'Айналма жолдан шығыңыз';

  @override
  String get navEnterRoundabout => 'Айналма жолға кіріңіз';

  @override
  String navRoundaboutExit(int exitNumber) {
    return 'Айналма жолда $exitNumber-шы шығуға бұрылыңыз';
  }

  @override
  String get navUTurn => 'Кері бұрылыңыз';

  @override
  String get navKeepLeft => 'Сол жақпен жүріңіз';

  @override
  String get navKeepRight => 'Оң жақпен жүріңіз';

  @override
  String get navContinue => 'Жүре беріңіз';

  @override
  String get navMergeLeft => 'Сол жақтан жол ағымына қосылыңыз';

  @override
  String get navMergeRight => 'Оң жақтан жол ағымына қосылыңыз';

  @override
  String get navMerge => 'Жол ағымына қосылыңыз';

  @override
  String get navOnRamp => 'Кірме жолға шығыңыз';

  @override
  String get navOffRamp => 'Шығу жолына бұрылыңыз';

  @override
  String get navStraight => 'Тура жүре беріңіз';

  @override
  String get navTurnSharpLeft => 'Солға күрт бұрылыңыз';

  @override
  String get navTurnSharpRight => 'Оңға күрт бұрылыңыз';

  @override
  String get navTurnSlightLeft => 'Солға сәл бұрылыңыз';

  @override
  String get navTurnSlightRight => 'Оңға сәл бұрылыңыз';

  @override
  String get navTurnLeft => 'Солға бұрылыңыз';

  @override
  String get navTurnRight => 'Оңға бұрылыңыз';

  @override
  String navDistanceMeters(int value) {
    return '$value м кейін';
  }

  @override
  String navDistanceKilometers(String value) {
    return '$value км кейін';
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
    return '$hours сағ $minutes мин';
  }

  @override
  String navRemaining(String summary) {
    return 'Қалды: $summary';
  }

  @override
  String get mapAddAddress => 'Мекенжай қосу';

  @override
  String mapStopNumber(int number) {
    return '$number-аялдама';
  }

  @override
  String get mapFinalDestination => 'Соңғы нүкте';

  @override
  String get mapRemoveStop => 'Аялдаманы жою';

  @override
  String get mapChooseAllStops => 'Әр аялдаманың мекенжайын таңдаңыз.';

  @override
  String get driverMapNextStop => 'Келесі аялдама';

  @override
  String get intercityOpenChat => 'Чатты ашу';

  @override
  String get intercityWhatsApp => 'WhatsApp-қа жазу';

  @override
  String get intercityWhatsAppUnavailable => 'WhatsApp ашылмады.';

  @override
  String get intercityNavigationUnavailable =>
      'Бұл сапардың соңғы нүктесінің координаттары көрсетілмеген.';

  @override
  String get intercityNavigationTitle => 'Қалааралық навигация';

  @override
  String get intercityNextPoint => 'Келесі нүкте';

  @override
  String get intercityFinishRide => 'Сапарды аяқтау';

  @override
  String get pushIntercityTripCompleted => 'Қалааралық сапар аяқталды';

  @override
  String get pushIntercityChatMessage => 'Сапар бойынша жаңа хабарлама';

  @override
  String get intercityContinueActiveTrip => 'Сапарды жалғастыру';

  @override
  String get intercityMarkPickupReached => 'Жолаушы алынды';

  @override
  String get intercityPickupReached => 'Жолаушы алынып қойды';

  @override
  String get intercityActiveTripUnknown =>
      'Белсенді сапарды тексеру мүмкін болмады. Қайталап көріңіз.';

  @override
  String get cityCancelTripTitle => 'Сапарды тоқтату керек пе?';

  @override
  String get cityCancelTripWarning =>
      'Сапар басталып кетті. Оны тек қажет болған жағдайда тоқтатыңыз.';

  @override
  String get cityCancelReasonLabel => 'Тоқтату себебін таңдаңыз';

  @override
  String get cityCancelReasonRequired => 'Сапарды тоқтату себебін таңдаңыз.';

  @override
  String get cityCancelReasonPlansChanged => 'Жоспар өзгерді';

  @override
  String get cityCancelReasonCarProblem => 'Көлікке қатысты мәселе';

  @override
  String get cityCancelReasonDriverProblem => 'Жүргізушіге қатысты мәселе';

  @override
  String get cityCancelReasonCarBreakdown => 'Көлік бұзылды';

  @override
  String get cityCancelReasonRoadIncident => 'Жол апаты / жолдағы жағдай';

  @override
  String get cityCancelReasonPassengerRequested => 'Жолаушы тоқтатуды сұрады';

  @override
  String get cityCancelReasonPassengerProblem => 'Жолаушыға қатысты мәселе';

  @override
  String get cityCancelReasonEmergency => 'Төтенше жағдай';

  @override
  String get cityCancelReasonOther => 'Басқа себеп';

  @override
  String get cityCancelReasonDetails => 'Себебін сипаттаңыз (міндетті емес)';

  @override
  String get cityCancelFinalConfirmation =>
      'Басталған сапарды тоқтатуды растайсыз ба?';

  @override
  String get pushCityCancelledByPassenger => 'Тапсырысты жолаушы тоқтатты';

  @override
  String get pushCityCancelledByDriver => 'Жүргізуші сапарды тоқтатты';

  @override
  String get deliveryRouteSection => 'Бағыт';

  @override
  String get deliveryParcelSection => 'Не жеткіземіз';

  @override
  String get deliveryContactsSection => 'Байланыс деректері';

  @override
  String get deliverySenderSection => 'Жіберуші';

  @override
  String get deliverySenderCurrentUser =>
      'Сіз — тапсырысты рәсімдеген пайдаланушы';

  @override
  String get deliveryRecipientSection => 'Алушы';

  @override
  String get deliveryAdditionalSection => 'Қосымша мәліметтер';

  @override
  String get deliveryDetailsFilled => 'Толтырылған';

  @override
  String get deliveryPriceSection => 'Жеткізу құны';

  @override
  String get driverWorkCity => 'Жұмыс қаласы';

  @override
  String get driverWorkCityChangeFailed =>
      'Жұмыс қаласын өзгерту мүмкін болмады. Белсенді сапарды аяқтаңыз немесе кейінірек қайталаңыз.';

  @override
  String get citiesUnavailable =>
      'Қалалар тізімін жүктеу мүмкін болмады. Қайталап көріңіз.';

  @override
  String get termsTitle => 'Пайдалану шарттары';

  @override
  String termsBody(String version) {
    return '$version нұсқасы. Хабарламалар, пікірлер және басқа контент жарияламас бұрын MEKEN шарттарымен танысыңыз. Қорлау, қоқан-лоқы, спам, заңсыз немесе қауіпті контент жарияламаңыз. Контентке шағым беруге немесе басқа пайдаланушыны бұғаттауға болады. Толық мәтін MEKEN құжаттарында сақталған.';
  }

  @override
  String get termsConfirm => 'Пайдалану шарттарын оқыдым және қабылдаймын';

  @override
  String get termsAccept => 'Қабылдау';

  @override
  String get termsAcceptFailed =>
      'Шарттарды қабылдауды сақтау мүмкін болмады. Қайталап көріңіз.';

  @override
  String get reportUser => 'Шағымдану';

  @override
  String get blockUser => 'Пайдаланушыны бұғаттау';

  @override
  String get blockUserConfirm =>
      'Бұл пайдаланушыны болашақ сапарлар мен сапардан кейінгі байланыс үшін бұғаттау керек пе?';

  @override
  String get reportSent => 'Шағым жіберілді';

  @override
  String get userBlocked => 'Пайдаланушы бұғатталды';

  @override
  String get reportReasonAbuse => 'Қорлау';

  @override
  String get reportReasonHarassment => 'Қудалау';

  @override
  String get reportReasonSpam => 'Спам';

  @override
  String get reportReasonUnsafe => 'Қауіпті мінез-құлық';

  @override
  String get reportReasonInappropriate => 'Орынсыз контент';

  @override
  String get reportReasonOther => 'Басқа себеп';

  @override
  String get aboutSupportTitle => 'Қолданба және қолдау';

  @override
  String get legalTerms => 'Пайдалану шарттары';

  @override
  String get legalTermsHint => 'Өзекті толық мәтінді ашу';

  @override
  String get legalPrivacy => 'Құпиялық саясаты';

  @override
  String get legalPrivacyHint => 'MEKEN деректеріңізді қалай өңдейді';

  @override
  String get legalAccountDeletion => 'Аккаунтты жою';

  @override
  String get legalAccountDeletionHint =>
      'Жою нұсқаулығы және жалпыға қолжетімді бет';

  @override
  String get legalSupport => 'Қолдау қызметі';

  @override
  String get legalSupportPending =>
      'Байланыс дерегі шығарылымға дейін жарияланады';

  @override
  String get legalVersion => 'Қолданба нұсқасы';

  @override
  String get legalOpenFailed => 'Сілтемені ашу мүмкін болмады';
}
