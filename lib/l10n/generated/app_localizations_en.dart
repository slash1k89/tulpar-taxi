// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loginTitle => 'Sign in';

  @override
  String get verificationTitle => 'Verify your number';

  @override
  String get profileTitle => 'What should we call you?';

  @override
  String get phoneHint =>
      'You\'ll receive a brief phone call.\nEnter the last 4 digits of the caller\'s number.';

  @override
  String get codeHint => 'Enter the last 4 digits of the caller\'s number';

  @override
  String get profileHint => 'Your name will appear on your profile.';

  @override
  String get requestCode => 'Get code by call';

  @override
  String get confirm => 'Confirm';

  @override
  String get continueLabel => 'Continue';

  @override
  String resendIn(int seconds) {
    return 'Call again in $seconds sec.';
  }

  @override
  String get resend => 'Call again';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get lastFourDigits => 'Last 4 digits';

  @override
  String get nameLabel => 'Name';

  @override
  String get invalidPhone => 'Enter a valid phone number.';

  @override
  String get invalidCode => 'Enter the last 4 digits of the caller\'s number.';

  @override
  String get invalidName => 'Enter a name between 2 and 120 characters.';

  @override
  String get resendCooldown => 'You can\'t request another call yet.';

  @override
  String get checkPhone => 'Check your phone number.';

  @override
  String get invalidVerification => 'The code is incorrect or has expired.';

  @override
  String get loginFailed => 'Couldn\'t sign in. Please try again.';

  @override
  String get serverTimeout => 'The server didn\'t respond. Please try again.';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get languageSetting => 'Language';

  @override
  String get registerTitle => 'Register';

  @override
  String get createAccount => 'Create an account';

  @override
  String get registerButton => 'Register';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authResetPasswordTitle => 'Reset password';

  @override
  String get authCreatePasswordTitle => 'Create a password';

  @override
  String get authVerificationPhoneHint =>
      'Enter your number to verify it by call.';

  @override
  String get authPasswordTooShort => 'Password must be at least 8 characters.';

  @override
  String get authInvalidCredentials => 'Incorrect phone number or password.';

  @override
  String get authPasswordAlreadySet =>
      'A password is already set. Use password recovery.';

  @override
  String get authVerificationRequired => 'Verify your number again.';

  @override
  String get authBackToLogin => 'Back to sign in';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get enterName => 'Enter your name';

  @override
  String get nameTooLong => 'Name is too long';

  @override
  String get enterPhone => 'Enter your phone number';

  @override
  String get enterFullPhone => 'Enter your full phone number';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get shortPassword => 'Password must be at least 6 characters';

  @override
  String get passwordMismatch => 'Passwords don\'t match';

  @override
  String registrationSuccess(String phone) {
    return 'Account created: $phone';
  }

  @override
  String get pushOpen => 'Open';

  @override
  String get pushDriverApproachingTitle => 'Driver almost there';

  @override
  String get pushDriverApproachingBody =>
      'Please head to the pickup point — your driver is approaching.';

  @override
  String get pushNewMessage => 'New chat message';

  @override
  String get pushOrderAccepted => 'Your driver is on the way';

  @override
  String get pushDeliveryAccepted =>
      'The courier is coming to collect the package';

  @override
  String get pushDriverArrived => 'Your driver is waiting at the pickup point!';

  @override
  String get pushDeliveryArrived =>
      'The courier arrived to collect the package';

  @override
  String get pushTripStarted => 'Trip started';

  @override
  String get pushDeliveryStarted => 'Your package is on the way';

  @override
  String get pushTripCompleted => 'Trip completed!';

  @override
  String get pushDeliveryCompleted => 'Delivery completed';

  @override
  String get pushOrderCancelled => 'Order cancelled';

  @override
  String get pushNewDriverOrder => 'New order';

  @override
  String get pushDriverHeading => 'Your driver is heading to the pickup point.';

  @override
  String get pushIntercityMatch => 'A matching intercity ride is available';

  @override
  String get pushIntercityCancelled =>
      'The driver cancelled the intercity ride';

  @override
  String get pushIntercityDeparted => 'The intercity ride has started';

  @override
  String get pushIntercityBooked => 'New intercity booking';

  @override
  String get pushIntercityBookingCancelled => 'Intercity booking cancelled';

  @override
  String get serviceCity => 'Taxi';

  @override
  String get serviceDelivery => 'Delivery';

  @override
  String get serviceIntercity => 'Intercity';

  @override
  String get driverCityOrders => 'Taxi orders';

  @override
  String get driverDeliveryOrders => 'Delivery orders';

  @override
  String driverNewOrder(String service) {
    return 'New order — $service';
  }

  @override
  String get statusSearchingDriver => 'Looking for an available driver...';

  @override
  String get statusSearchingCourier => 'Looking for an available courier...';

  @override
  String get statusSearchingIntercity => 'Looking for an intercity driver...';

  @override
  String get statusCourierComing =>
      'The courier is coming to collect the package';

  @override
  String get statusDriverComing => 'Your driver is on the way';

  @override
  String get statusCourierArrived =>
      'The courier arrived to collect the package';

  @override
  String get statusDriverArrived =>
      'Your driver is waiting at the pickup point!';

  @override
  String get statusIntercityDriverArrived => 'The driver has arrived';

  @override
  String get statusHandPackage => 'Please hand the package to the courier';

  @override
  String get statusGoToCar => 'Please head to the car';

  @override
  String get statusPackageOnWay => 'Your package is on the way';

  @override
  String get statusTripInProgress => 'Trip in progress';

  @override
  String get statusTripStarted => 'Trip started';

  @override
  String get statusDeliveryCompleted => 'Delivery completed';

  @override
  String get statusTripCompleted => 'Trip completed!';

  @override
  String get statusIntercityCompleted => 'Intercity trip completed';

  @override
  String get statusDriverFinishingPrevious =>
      'Your driver is finishing a previous trip';

  @override
  String get cancelOrderTitle => 'Cancel order';

  @override
  String get confirmCancelOrder =>
      'Are you sure you want to cancel this order?';

  @override
  String get no => 'No';

  @override
  String get yesCancel => 'Yes, cancel';

  @override
  String offerAccepted(String driver, String price) {
    return '$driver: offer of $price ₸ accepted.';
  }

  @override
  String get close => 'Close';

  @override
  String get cancelOrderFailed =>
      'Couldn\'t cancel the order. Check your connection and try again.';

  @override
  String get yourOrder => 'Your order';

  @override
  String get orderCancelled => 'Order cancelled';

  @override
  String get orderLoadFailed => 'Couldn\'t load order details';

  @override
  String get invalidOrderCoordinates => 'Order location is invalid';

  @override
  String get cancelling => 'Cancelling...';

  @override
  String get cancelSearch => 'Cancel search';

  @override
  String get queuedOrderHint =>
      'Your driver will head to you as soon as the previous trip ends.';

  @override
  String get cancelOrder => 'Cancel order';

  @override
  String recipientAddress(String address) {
    return 'Recipient address: $address';
  }

  @override
  String directionAddress(String address) {
    return 'Destination: $address';
  }

  @override
  String get addressUnknown => 'Address not provided';

  @override
  String orderStatusUnknown(String status) {
    return 'Order status: $status';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get courier => 'Courier';

  @override
  String get driver => 'Driver';

  @override
  String get car => 'Car';

  @override
  String fromAddress(String address) {
    return 'From: $address';
  }

  @override
  String toAddress(String address) {
    return 'To: $address';
  }

  @override
  String priceTenge(String price) {
    return 'Price: $price ₸';
  }

  @override
  String get carLoading => 'Loading car details...';

  @override
  String get driverProfile => 'Driver profile';

  @override
  String get chat => 'Chat';

  @override
  String get taxiAndDelivery => 'Taxi and delivery';

  @override
  String get chatInvalidLength =>
      'Messages must be between 1 and 2000 characters.';

  @override
  String get chatInvalidRequest => 'The request data is invalid.';

  @override
  String get chatForbidden => 'You don\'t have access to this order.';

  @override
  String get chatOrderNotFound => 'Order not found.';

  @override
  String get chatSendFailed => 'Couldn\'t send the message.';

  @override
  String chatRateLimited(int seconds) {
    return 'Too many messages. Try again in $seconds seconds.';
  }

  @override
  String get retry => 'Retry';

  @override
  String get chatEmpty => 'No messages yet. Say hello!';

  @override
  String get chatMessageHint => 'Message...';

  @override
  String get mapDeliveryPriceRequired => 'Enter a delivery price.';

  @override
  String get mapTripPriceRequired => 'Enter a trip price.';

  @override
  String get mapLocationSlow =>
      'Couldn\'t find your location quickly. Choose an address manually.';

  @override
  String mapOutsideCity(String city) {
    return 'Your location is outside $city.';
  }

  @override
  String mapChoosePointInCity(String city) {
    return 'Choose a point in $city.';
  }

  @override
  String get mapResolvingAddress => 'Finding address...';

  @override
  String get mapChoosePointInKazakhstan => 'Choose a point within Kazakhstan.';

  @override
  String get mapPickupCity => 'Departure city';

  @override
  String get mapDestinationCity => 'Destination city';

  @override
  String get mapChooseCity => 'Choose a city';

  @override
  String get mapRouteFailed => 'Couldn\'t build the route. Please try again.';

  @override
  String get mapChooseFutureTime => 'Choose a future time.';

  @override
  String get mapChooseBothCities =>
      'Choose departure and destination cities first.';

  @override
  String get mapChooseRoutePoints =>
      'Select points A and B on the map or from the list.';

  @override
  String get mapPointA => 'Point A';

  @override
  String get mapPointB => 'Point B';

  @override
  String get mapServerTimeout =>
      'The server didn\'t respond. Please try again.';

  @override
  String get mapStaleOrder =>
      'An old order link was found and wasn\'t removed automatically. Contact support to have it checked.';

  @override
  String mapServiceInCity(String service, String city) {
    return '$service — $city';
  }

  @override
  String get mapExactPickupAddress => 'Exact pickup address';

  @override
  String get mapChooseAddress => 'Choose an address';

  @override
  String get mapExactDeliveryAddress => 'Exact delivery address';

  @override
  String get mapExactDestinationAddress => 'Exact destination address';

  @override
  String get mapRecipientApartment => 'Recipient\'s apartment (optional)';

  @override
  String get mapPackageDescription => 'Package description';

  @override
  String get mapPackageExample => 'For example: documents';

  @override
  String get mapRecipientName => 'Recipient\'s name';

  @override
  String get mapRecipientPhone => 'Recipient\'s phone';

  @override
  String get mapPassengerCount => 'Number of passengers';

  @override
  String get mapHasLuggage => 'Travelling with luggage';

  @override
  String get mapOptionalComment => 'Comment (optional)';

  @override
  String get mapYourPrice => 'Your price (₸)';

  @override
  String get mapRequestDelivery => 'Request delivery';

  @override
  String get mapRequestIntercity => 'Request an intercity ride';

  @override
  String get mapRequestTaxi => 'Request a taxi';

  @override
  String get orderErrorLogin => 'Sign in and try again.';

  @override
  String get orderErrorActive => 'You already have an active order.';

  @override
  String get orderErrorInvalid =>
      'Check the addresses, price, and route points.';

  @override
  String get orderErrorDelivery =>
      'Enter the package description and recipient\'s name and phone number.';

  @override
  String get orderErrorIntercity =>
      'Check the intercity trip time and details.';

  @override
  String get orderErrorPermission =>
      'You don\'t have permission to create an order.';

  @override
  String get orderErrorUnavailable =>
      'Couldn\'t reach the server. Please try again.';

  @override
  String get orderErrorUnknown =>
      'Couldn\'t create the order. Please try again.';

  @override
  String get driverAcceptDelivery =>
      'Delivery accepted! Head to the pickup point for the package.';

  @override
  String get driverAcceptIntercity =>
      'Intercity ride accepted! Head to the passenger.';

  @override
  String get driverAcceptCity => 'Order accepted! Head to the passenger.';

  @override
  String get driverAcceptFailed =>
      'Couldn\'t accept the order. Please try again.';

  @override
  String get driverProposePrice => 'Offer a price';

  @override
  String get driverSendOffer => 'Send';

  @override
  String get pickerResolvingAddress => 'Finding address...';

  @override
  String get pickerAddressUnavailable =>
      'Couldn\'t find the address. Coordinates were saved.';

  @override
  String get pickerAddressTimeout =>
      'The address service didn\'t respond. Coordinates were saved.';

  @override
  String pickerCoordinate(String latitude, String longitude) {
    return 'Point on map ($latitude, $longitude)';
  }

  @override
  String pickerChooseInCity(String city) {
    return 'Choose a point in $city.';
  }

  @override
  String get pickerCityCheckFailed =>
      'Couldn\'t check the city. Check your connection and try again.';

  @override
  String get pickerPointCheckFailed =>
      'Couldn\'t check the point. Please try again.';

  @override
  String get pickerEnableLocation => 'Turn on location services on your phone.';

  @override
  String get pickerLocationDenied => 'Location access wasn\'t granted.';

  @override
  String get pickerLocationSettings =>
      'Allow location access in the app settings.';

  @override
  String get pickerLocationSlow =>
      'Couldn\'t find your location quickly. Choose a point manually.';

  @override
  String get pickerLocationFailed =>
      'Couldn\'t find your location. Choose a point manually.';

  @override
  String get pickerNoLocation =>
      'Couldn\'t get your location. Choose a point manually.';

  @override
  String get pickerCityCheckManual =>
      'Couldn\'t check the city. Choose a point manually or retry.';

  @override
  String get pickerPickupTitle => 'Pickup point';

  @override
  String get pickerDestinationTitle => 'Destination';

  @override
  String get pickerMyLocation => 'My location';

  @override
  String get pickerChecking => 'Checking...';

  @override
  String get pickerChoosePoint => 'Choose this point';

  @override
  String get profileNotAuthenticated => 'User is not signed in';

  @override
  String get profileLoadFailed => 'Couldn\'t load profile';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get profileLegacyError =>
      'This profile uses an older format. If the error persists after entering your name, check the uid, phone, role and creation date in Firebase.';

  @override
  String profileSaveCodeError(String code) {
    return 'Couldn\'t save profile: $code.';
  }

  @override
  String get profileSaveFailed => 'Couldn\'t save profile.';

  @override
  String get profileDeleteTitle => 'Delete account?';

  @override
  String get profileDeleteFinalTitle => 'Really delete your account?';

  @override
  String get profileDeleteWarning =>
      'This can\'t be undone. Finish or cancel active orders and trips first.';

  @override
  String get profileDeleteFinalWarning =>
      'After continuing, your account and personal data can\'t be recovered.';

  @override
  String get profileYesDelete => 'Yes, delete';

  @override
  String get profileDeleteCallRequired =>
      'Deleting your account requires another phone-call confirmation.';

  @override
  String get profileDeleted => 'Account deleted.';

  @override
  String get profileDeletionPending =>
      'Deletion request accepted. Completing it may take some time.';

  @override
  String get profileDeleteFailed => 'Couldn\'t delete account.';

  @override
  String get profileSettingsTitle => 'Profile and settings';

  @override
  String get profileName => 'Name';

  @override
  String get profileEnterName => 'Enter your name';

  @override
  String get profileNameTooLong => 'Name is too long';

  @override
  String get profilePhone => 'Phone number';

  @override
  String get profilePhoneReadonly => 'Phone number can\'t be changed';

  @override
  String get profileCar => 'Car make and model';

  @override
  String get profileTheme => 'Theme';

  @override
  String get profileThemeSystem => 'Use system setting';

  @override
  String get profileThemeLight => 'Light';

  @override
  String get profileThemeDark => 'Dark';

  @override
  String get profileVoice => 'Voice guidance';

  @override
  String get profileVoiceHint => 'Speak navigation maneuvers aloud';

  @override
  String get profileSave => 'Save details';

  @override
  String get profilePasswordTitle => 'Confirm password';

  @override
  String get profileCurrentPassword => 'Current password';

  @override
  String get profileEnterPassword => 'Enter password';

  @override
  String unreadMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '$count unread message',
    );
    return '$_temp0';
  }

  @override
  String get agreementSaveFailed =>
      'Couldn\'t save your agreement. Please try again.';

  @override
  String get agreementRulesTitle => 'Driver rules';

  @override
  String agreementVersion(String version) {
    return 'Agreement version $version';
  }

  @override
  String get agreementBody =>
      'By switching to driver mode, I confirm that:\n\n• I may legally drive and use a roadworthy vehicle;\n\n• I follow traffic laws and safety requirements;\n\n• I keep my vehicle clean and treat passengers courteously;\n\n• I do not go online when unfit to drive safely;\n\n• I provide accurate vehicle details and do not share my account;\n\n• I use passenger data only to complete the order.';

  @override
  String get agreementConfirm =>
      'I have read the rules and accept the agreement';

  @override
  String get agreementAcceptContinue => 'Accept and continue';

  @override
  String get onboardingLoginRequired => 'Sign in to enable driver mode.';

  @override
  String get onboardingServerTimeout =>
      'The server didn\'t respond. Check your connection and retry.';

  @override
  String get onboardingLoadFailed => 'Couldn\'t load the driver profile.';

  @override
  String get onboardingActivated => 'Driver profile activated';

  @override
  String get onboardingRetryTimeout =>
      'The server didn\'t respond. Please try again.';

  @override
  String get onboardingSubmitFailed =>
      'Couldn\'t submit your driver application.';

  @override
  String get onboardingPermissionDenied =>
      'You don\'t have permission to change this driver profile.';

  @override
  String get onboardingUnavailable =>
      'The service is temporarily unavailable. Check your connection.';

  @override
  String onboardingFirebaseError(String code) {
    return 'Firebase error: $code. Please try again.';
  }

  @override
  String get onboardingPendingTitle => 'Driver application sent for review.';

  @override
  String get onboardingPendingBody =>
      'Driver mode will become available automatically once approved. You won\'t need to enter the agreement or vehicle details again.';

  @override
  String get onboardingCheckStatus => 'Check status';

  @override
  String get onboardingSuspendedTitle => 'Driver access suspended.';

  @override
  String get onboardingSuspendedBody =>
      'You can\'t accept orders right now. Contact a MEKEN administrator for details.';

  @override
  String get onboardingCheckAgain => 'Check again';

  @override
  String get onboardingDriverMode => 'Driver mode';

  @override
  String get onboardingVehicleTitle => 'Driver vehicle';

  @override
  String get onboardingFillVehicle => 'Enter vehicle details';

  @override
  String get onboardingVehicleHint =>
      'After submission, your application will be reviewed. Passengers will only see these details after you accept an order.';

  @override
  String get onboardingCarModel => 'Make and model';

  @override
  String get onboardingCarModelRequired => 'Enter vehicle make and model';

  @override
  String get onboardingCarColor => 'Body color';

  @override
  String get onboardingCarColorRequired => 'Enter vehicle color';

  @override
  String get onboardingCarNumber => 'License plate';

  @override
  String get onboardingCarNumberRequired => 'Enter the license plate';

  @override
  String get onboardingSubmit => 'Submit application for review';

  @override
  String get drawerEnabled => 'On';

  @override
  String get drawerDisabled => 'Off';

  @override
  String get drawerHistory => 'Order history';

  @override
  String get drawerSignOut => 'Sign out';

  @override
  String deliveryPackage(String description) {
    return 'Package: $description';
  }

  @override
  String deliveryRecipient(String name) {
    return 'Recipient: $name';
  }

  @override
  String deliveryPhone(String phone) {
    return 'Phone: $phone';
  }

  @override
  String get deliveryCallRecipient => 'Call recipient';

  @override
  String deliveryApartment(String apartment) {
    return 'Apartment: $apartment';
  }

  @override
  String get deliveryDialerFailed => 'Couldn\'t open the calling app.';

  @override
  String intercityKazakhstanTime(String time) {
    return '$time · Kazakhstan time';
  }

  @override
  String intercityPassengers(int count) {
    return 'Passengers: $count';
  }

  @override
  String get intercityHasLuggage => 'Has luggage';

  @override
  String intercityComment(String comment) {
    return 'Comment: $comment';
  }

  @override
  String intercityPrice(int price) {
    return 'Price: $price ₸';
  }

  @override
  String get intercitySearchCityHint => 'City or settlement';

  @override
  String get intercityStreetHouseHint => 'Street and house number';

  @override
  String get intercityChooseOnMap => 'Choose on map';

  @override
  String get profileWrongPassword => 'Incorrect password.';

  @override
  String get profileTooManyAttempts => 'Too many attempts. Try again later.';

  @override
  String get profileNetworkError => 'No network connection. Please try again.';

  @override
  String get profileUserDisabled => 'This account is disabled.';

  @override
  String get profileUserNotFound => 'Couldn\'t confirm the current account.';

  @override
  String get profileRecentLoginRequired => 'Please sign in again.';

  @override
  String get profileReauthFailed => 'Couldn\'t confirm the password.';

  @override
  String get profileDeletionUnknown =>
      'Couldn\'t confirm the deletion result. Check your account status later.';

  @override
  String get intercityOrderCar => 'Book a whole car';

  @override
  String get intercityOrderCarHint => 'A private car to your address';

  @override
  String get intercityFindRide => 'Find a shared ride';

  @override
  String get intercityFindRideHint => 'Reserve a seat on a driver\'s trip';

  @override
  String get intercityMyBookings => 'My bookings';

  @override
  String get intercityLookingForRide => 'Looking for a ride';

  @override
  String get intercityChooseCities =>
      'Choose departure and destination cities.';

  @override
  String get intercityDifferentCities =>
      'Departure and destination cities must be different.';

  @override
  String get intercityDatePast => 'Travel date can\'t be in the past.';

  @override
  String get intercitySeatsRange => 'Choose 1 to 7 seats.';

  @override
  String get intercityFrom => 'From';

  @override
  String get intercityTo => 'To';

  @override
  String get intercityTravelDate => 'Travel date';

  @override
  String get intercityFindTrips => 'Find trips';

  @override
  String get intercitySeatCount => 'Number of seats';

  @override
  String get intercityDecrease => 'Decrease';

  @override
  String get intercityIncrease => 'Increase';

  @override
  String intercitySeatSemantics(int count) {
    return 'Number of seats: $count';
  }

  @override
  String get intercityMatchingTrips => 'Matching trips';

  @override
  String get intercityTripsLoadFailed => 'Couldn\'t load trips';

  @override
  String get intercityNoTrips => 'No matching trips yet';

  @override
  String get intercityLeaveRequest => 'Leave a request';

  @override
  String intercityAvailableSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats available',
      one: '$count seat available',
    );
    return '$_temp0';
  }

  @override
  String intercityPerSeat(String price) {
    return '$price / seat';
  }

  @override
  String get intercityDetails => 'Details';

  @override
  String get datePreviousMonth => 'Previous month';

  @override
  String get dateNextMonth => 'Next month';

  @override
  String get dateDone => 'Done';

  @override
  String get historyNoAddress => 'Address not provided';

  @override
  String get historyDriverRole => 'I was the driver';

  @override
  String get historyPassengerRole => 'I was the passenger';

  @override
  String get historyTitle => 'Trip history';

  @override
  String get historyLoadFailed => 'Couldn\'t load trip history.';

  @override
  String get historyEmpty => 'You have no completed trips yet';

  @override
  String get historyCompleted => 'Completed';

  @override
  String get historyCancelled => 'Cancelled';

  @override
  String historyPrice(String price) {
    return '$price ₸';
  }

  @override
  String get driverMapActionFailed =>
      'Couldn\'t update the order. Please try again.';

  @override
  String get driverMapRerouteFailed => 'Couldn\'t update the route';

  @override
  String get driverMapCustomer => 'customer';

  @override
  String get driverMapNextLoadFailed =>
      'Next order accepted, but its details couldn\'t be loaded.';

  @override
  String get driverMapNextAccepted => 'Next order accepted';

  @override
  String get driverMapNextUnavailable => 'Order is no longer available';

  @override
  String get driverMapOwnPrice => 'Your price';

  @override
  String get driverMapPriceLabel => 'Price, ₸';

  @override
  String get driverMapOfferSent => 'Offer sent to the passenger';

  @override
  String get driverMapArrivedAction => 'I\'ve arrived';

  @override
  String get driverMapPackageReceived => 'Package collected';

  @override
  String get driverMapStartTrip => 'Start trip';

  @override
  String get driverMapCompleteDelivery => 'Complete delivery';

  @override
  String get driverMapCompleteTrip => 'Complete trip';

  @override
  String get driverMapDeliveryTitle => 'Delivery in progress';

  @override
  String get driverMapIntercityTitle => 'Intercity trip';

  @override
  String get driverMapCityTitle => 'Order in progress';

  @override
  String driverMapCollectPackage(String address) {
    return 'Collect the package: $address';
  }

  @override
  String driverMapClientWaiting(String address) {
    return 'Passenger waiting: $address';
  }

  @override
  String get orderOfferAcceptFailed =>
      'Couldn\'t accept the offer. Please try again.';

  @override
  String get trackingStopped => 'Location tracking has stopped.';

  @override
  String get trackingSignIn => 'Sign in to your driver account.';

  @override
  String get trackingEnableServices => 'Turn on location services.';

  @override
  String get trackingAllowLocation => 'Allow location access.';

  @override
  String get trackingAllowInSettings =>
      'Allow location access in the app settings.';

  @override
  String get trackingPositionFailed =>
      'Couldn\'t get or send your current location.';

  @override
  String get driverChangeOffer => 'Change offer';

  @override
  String driverPassengerPrice(int price) {
    return 'Passenger\'s price: $price ₸';
  }

  @override
  String get driverYourPrice => 'Your price, ₸';

  @override
  String get driverEnterWholeAmount => 'Enter a whole amount.';

  @override
  String get driverOfferAbovePrice =>
      'Your offer must be higher than the passenger\'s price.';

  @override
  String get driverOfferTooHigh => 'Your offer cannot exceed 1,000,000 ₸.';

  @override
  String driverOfferSent(int price) {
    return 'Your offer of $price ₸ was sent to the passenger.';
  }

  @override
  String get driverOfferFailed => 'Couldn\'t send the offer. Please try again.';

  @override
  String get driverNotAuthenticated => 'Driver is not signed in';

  @override
  String get driverOnline => 'Online';

  @override
  String get driverActiveCheckFailed =>
      'Couldn\'t check the current order. We\'ll retry automatically.';

  @override
  String get driverNoOrders => 'No available orders yet';

  @override
  String get passenger => 'Passenger';

  @override
  String distanceKilometers(String distance) {
    return '$distance km';
  }

  @override
  String pricePerKilometer(int price) {
    return '$price ₸/km';
  }

  @override
  String driverYouOffered(int price) {
    return 'You offered $price ₸';
  }

  @override
  String get driverChangePrice => 'Change price';

  @override
  String driverAcceptForPrice(int price) {
    return 'Accept for $price ₸';
  }

  @override
  String get driverOrdersForbidden =>
      'No access to orders. The driver profile must be approved.';

  @override
  String get driverOrdersConfigFailed =>
      'Order requests are unavailable. Check the service configuration.';

  @override
  String get driverOrdersTimeout =>
      'The server didn\'t respond in time. We\'ll retry checking orders automatically.';

  @override
  String get driverOrdersLoadFailed =>
      'Couldn\'t refresh available orders. We\'ll retry automatically.';

  @override
  String get bookingCancelTitle => 'Cancel booking?';

  @override
  String get bookingBack => 'Back';

  @override
  String get bookingCancelExplanation =>
      'The reserved seats will become available again.';

  @override
  String get bookingCancel => 'Cancel booking';

  @override
  String get bookingCancelFailed =>
      'Could not cancel the booking. Please try again.';

  @override
  String get bookingLoadFailed => 'Could not load bookings';

  @override
  String get bookingEmpty => 'You have no bookings yet';

  @override
  String bookingSeatsAndPrice(int count, String price) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats',
      one: '$count seat',
    );
    return '$_temp0 · $price';
  }

  @override
  String bookingPickup(String address) {
    return 'Pickup point: $address';
  }

  @override
  String bookingComment(String comment) {
    return 'Note to driver: $comment';
  }

  @override
  String bookingDriver(String name) {
    return 'Driver: $name';
  }

  @override
  String bookingPhone(String phone) {
    return 'Phone: $phone';
  }

  @override
  String get bookingUpcoming => 'Upcoming';

  @override
  String get bookingCancelled => 'Cancelled';

  @override
  String get bookingCompleted => 'Completed';

  @override
  String get bookingOther => 'Other';

  @override
  String get profileActiveOrder =>
      'Complete or cancel your current order first.';

  @override
  String get profileActiveDriverOrder =>
      'Complete your active driver order first.';

  @override
  String get profileActiveRide => 'Complete or cancel your shared ride first.';

  @override
  String get profileActiveBooking => 'Complete or cancel your booking first.';

  @override
  String get profileActiveRideRequest =>
      'Cancel your active shared-ride request first.';

  @override
  String get profileDeletionManualReview =>
      'Account deletion requires support review.';

  @override
  String get driverIntercityOrders => 'Passenger orders';

  @override
  String get driverIntercityOrdersHint => 'Standard intercity orders';

  @override
  String get driverIntercityMyRides => 'My rides';

  @override
  String get driverIntercityMyRidesHint =>
      'Published shared rides and bookings';

  @override
  String get driverIntercityCreateRide => 'Create a ride';

  @override
  String get driverIntercityCreateHint => 'Offer seats to fellow travelers';

  @override
  String get intercityPickupPoint => 'Pickup point';

  @override
  String get driverRidesEmpty => 'You haven\'t published any rides yet';

  @override
  String driverRideTotalSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats total',
      one: '$count seat total',
    );
    return '$_temp0';
  }

  @override
  String get driverRideScheduled => 'Scheduled';

  @override
  String get driverRideDeparted => 'On the way';

  @override
  String get driverRideCompleted => 'Completed';

  @override
  String get driverRideCancelled => 'Cancelled';

  @override
  String get driverRideUnknown => 'Unknown status';

  @override
  String get driverRideGroupDeparted => 'On the way';

  @override
  String get publicDriverLoadFailed => 'Could not load the driver\'s profile';

  @override
  String get publicDriverNoRatings => 'No ratings';

  @override
  String publicDriverRatingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ratings',
      one: '$count rating',
    );
    return '$_temp0';
  }

  @override
  String get publicDriverReviews => 'Reviews';

  @override
  String get publicDriverNoReviews => 'No reviews yet';

  @override
  String get ratingTitleDriver => 'Rate your driver';

  @override
  String get ratingCourierObject => 'your courier';

  @override
  String get ratingTitlePassenger => 'Rate your passenger';

  @override
  String ratingTitleName(String name) {
    return 'Rate $name';
  }

  @override
  String ratingStarTooltip(int score) {
    return '$score of 5';
  }

  @override
  String get ratingReviewHint => 'Write a review (optional)';

  @override
  String get ratingCancel => 'Cancel';

  @override
  String get ratingSubmit => 'Submit';

  @override
  String get ratingInvalidRequest => 'The request details are invalid.';

  @override
  String get ratingForbidden => 'You don\'t have permission to rate this trip.';

  @override
  String get ratingOrderMissing => 'The order to rate was not found.';

  @override
  String get ratingAlreadySent => 'You already rated this order.';

  @override
  String get ratingNotCompleted => 'Only completed orders can be rated.';

  @override
  String get ratingInvalidScore =>
      'Choose a rating from 1 to 5. Reviews must be 500 characters or less.';

  @override
  String get ratingFailed => 'Could not submit the rating. Please try again.';

  @override
  String get mapSelectedPoint => 'Selected point';

  @override
  String get mapPickupMarker => 'Pickup point';

  @override
  String get mapDestinationMarker => 'Destination point';

  @override
  String get mapUserMarker => 'Your location';

  @override
  String get mapCourierMarker => 'Courier on map';

  @override
  String get mapVehicleMarker => 'Vehicle on map';

  @override
  String get intercityPickupPrompt => 'Where should we pick you up?';

  @override
  String get requestSelectOriginFirst => 'Choose a departure city first.';

  @override
  String get requestFutureDate => 'Requests must be for a future date.';

  @override
  String get requestCommentTooLong =>
      'The note must be 1,000 characters or less.';

  @override
  String get requestSelectPickup => 'Choose a pickup point.';

  @override
  String get requestSaved => 'Request saved';

  @override
  String get requestDuplicate => 'An identical active request already exists.';

  @override
  String get requestSaveFailed =>
      'Could not save the request. Please try again.';

  @override
  String get requestCancelTitle => 'Cancel request?';

  @override
  String get requestCancelFailed =>
      'Could not cancel the request. Please try again.';

  @override
  String get requestNotifyHint =>
      'We\'ll let you know when a matching ride appears.';

  @override
  String get requestCommentLabel => 'Note to driver (optional)';

  @override
  String get requestCommentHint =>
      'For example, please come to the main entrance';

  @override
  String get requestMyRequests => 'My requests';

  @override
  String get requestLoadFailed => 'Could not load requests';

  @override
  String get requestEmpty => 'No active requests yet';

  @override
  String requestDateSeats(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats',
      one: '$count seat',
    );
    return '$date · $_temp0';
  }

  @override
  String get requestMatchedRides => 'Matching rides:';

  @override
  String requestMatchedRide(int number) {
    return 'Ride $number';
  }

  @override
  String get requestCancel => 'Cancel request';

  @override
  String get requestActive => 'Active';

  @override
  String get requestCancelled => 'Cancelled';

  @override
  String get requestExpired => 'Expired';

  @override
  String get recoveryCheckFailed =>
      'Could not check the profile. Check your connection and retry.';

  @override
  String get recoveryNameLimit => 'Enter a name of no more than 80 characters.';

  @override
  String get recoveryTitle => 'Restore profile';

  @override
  String get recoveryLegacyTitle => 'Profile uses an older format';

  @override
  String get recoveryEnterName => 'Enter your name';

  @override
  String get recoveryIncomplete => 'Could not complete the check';

  @override
  String get recoveryAdminBody =>
      'Protected fields cannot be safely restored from the phone. This profile needs a targeted administrative migration.';

  @override
  String get recoveryAdminFields => 'Require administrative restoration:';

  @override
  String get recoveryLegacyWarning =>
      'Legacy isDriver, driverActiveUntil and vehicle data were found, but are not used to grant driver access.';

  @override
  String get recoveryNameBody =>
      'Your name is missing from the profile and Firebase Auth. Enter your name; other protected fields will remain unchanged.';

  @override
  String get recoverySaveContinue => 'Save and continue';

  @override
  String get recoveryCheckAgain => 'Check again';

  @override
  String get recoverySignOut => 'Sign out';

  @override
  String get recoveryFieldUid => 'account ID (uid)';

  @override
  String get recoveryFieldName => 'name';

  @override
  String get recoveryFieldPhone => 'verified phone';

  @override
  String get recoveryFieldRole => 'base passenger role';

  @override
  String get recoveryFieldRating => 'initial rating 5.0';

  @override
  String get recoveryFieldCreatedAt => 'creation date from Firebase Auth';

  @override
  String get driverRideUpdated => 'Ride updated';

  @override
  String get driverRidePublished => 'Ride published';

  @override
  String get driverRideEditTitle => 'Edit ride';

  @override
  String get driverRideCreateTitle => 'Create ride';

  @override
  String get driverRideProtected =>
      'Route, time and seat count cannot be changed after a booking.';

  @override
  String get driverRideRoute => 'Route';

  @override
  String get driverRideDate => 'Date';

  @override
  String get driverRideTime => 'Time';

  @override
  String get driverRidePricePerSeat => 'Price per seat';

  @override
  String get driverRidePriceNotice =>
      'A new price will not change existing bookings.';

  @override
  String get driverRideLuggageAllowed => 'Luggage allowed';

  @override
  String get driverRideNoLuggage => 'No luggage';

  @override
  String get driverRideComment => 'Comment';

  @override
  String get driverRidePublish => 'Publish ride';

  @override
  String get driverRideChooseCities =>
      'Choose departure and destination cities.';

  @override
  String get driverRideDifferentCities =>
      'Departure and destination cities must be different.';

  @override
  String get driverRideFutureTime => 'Choose a future date and time.';

  @override
  String get driverRideSeatsRange => 'You can offer 1 to 7 seats.';

  @override
  String get driverRideInvalidPrice => 'Enter a valid price per seat.';

  @override
  String get driverRideCommentLong => 'The comment is too long.';

  @override
  String get driverRideInvalidData => 'Check the ride details.';

  @override
  String get driverRideLogin => 'Sign in and retry.';

  @override
  String get driverRideAccess => 'Driver access is not active.';

  @override
  String get driverRideMissing => 'Ride not found.';

  @override
  String get driverRideChanged => 'The ride has changed. Refresh its details.';

  @override
  String get driverRideSaveFailed => 'Could not save the ride.';

  @override
  String get driverRideServerTimeout =>
      'The server did not respond. Try again later.';

  @override
  String get bookingPickupCityFailed => 'Could not identify the pickup city.';

  @override
  String get bookingSelectPickup => 'Choose a pickup point.';

  @override
  String get bookingCommentLimit =>
      'The note must be 1,000 characters or less.';

  @override
  String get bookingConfirmTitle => 'Confirm booking?';

  @override
  String get bookingBook => 'Book';

  @override
  String get bookingBooked => 'Seat booked';

  @override
  String get bookingSavedBody => 'The booking was saved in My bookings.';

  @override
  String get bookingStay => 'Stay here';

  @override
  String get bookingRide => 'Ride';

  @override
  String get bookingLoadRideFailed => 'Could not load the ride';

  @override
  String bookingTotal(String price) {
    return 'Total: $price';
  }

  @override
  String bookingBookSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats',
      one: '$count seat',
    );
    return 'Book $_temp0';
  }

  @override
  String bookingConfirmSummary(String seats, String price, String address) {
    return '$seats · $price\n$address';
  }

  @override
  String get bookingRideChanged =>
      'The ride changed or there are not enough seats.';

  @override
  String get bookingLogin => 'Sign in and retry.';

  @override
  String get bookingServerTimeout => 'The server did not respond. Retry.';

  @override
  String get bookingFailed => 'Could not book a seat. Retry.';

  @override
  String get driverRideDetailsTitle => 'Ride details';

  @override
  String get driverRideStatusLabel => 'Status';

  @override
  String get driverRideDeparture => 'Departure';

  @override
  String get driverRideTotalSeatsLabel => 'Total seats';

  @override
  String get driverRideAvailableSeatsLabel => 'Available seats';

  @override
  String get driverRideBookedSeatsLabel => 'Booked seats';

  @override
  String get driverRideLuggage => 'Luggage';

  @override
  String get driverRideYes => 'Allowed';

  @override
  String get driverRideNo => 'No';

  @override
  String get driverRideVehicle => 'Vehicle';

  @override
  String get driverRidePassengers => 'Passengers';

  @override
  String get driverRideNoBookings => 'No seats booked yet';

  @override
  String get driverRideCancelTrip => 'Cancel ride';

  @override
  String get driverRideStartTrip => 'Start ride';

  @override
  String get driverRideFinishTrip => 'Complete ride';

  @override
  String get driverRideBookingConfirmed => 'Confirmed';

  @override
  String get driverRideBookingCancelled => 'Cancelled';

  @override
  String get driverRideBookingCompleted => 'Completed';

  @override
  String get driverRideBookingUnknown => 'Unknown status';

  @override
  String get driverRideCancelTitle => 'Cancel ride?';

  @override
  String get driverRideDepartTitle => 'Start ride?';

  @override
  String get driverRideCompleteTitle => 'Complete ride?';

  @override
  String get driverRideCancelAction => 'Cancel';

  @override
  String get driverRideDepartAction => 'Start';

  @override
  String get driverRideCompleteAction => 'Complete';

  @override
  String get driverRideCancelBookingsWarning =>
      'All passenger bookings will be cancelled.';

  @override
  String get driverRideCancelNoBookings =>
      'The ride will no longer be available to passengers.';

  @override
  String get driverRideDepartWarning =>
      'After departure, new bookings and passenger cancellations will be unavailable.';

  @override
  String get driverRideCompleteWarning => 'Confirm that the ride is complete.';

  @override
  String driverRideBookingSummary(int count, String price) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats',
      one: '$count seat',
    );
    return '$_temp0 · $price';
  }

  @override
  String driverRidePassengerName(String name) {
    return 'Passenger: $name';
  }

  @override
  String driverRidePickupComment(String comment) {
    return 'Passenger note: $comment';
  }

  @override
  String get driverRideShowMap => 'Show on map';

  @override
  String get navigationGpsRequired => 'GPS permission is required';

  @override
  String get navigationRecalculating => 'Recalculating route...';

  @override
  String get navigationRecalculateFailed => 'Could not recalculate the route.';

  @override
  String get navigationTitle => 'Order navigation';

  @override
  String get navigationMapPlaceholder => 'Map appears here';

  @override
  String get timePickerChoose => 'Choose time';

  @override
  String get timePickerHours => 'Hours';

  @override
  String get timePickerMinutes => 'Minutes';

  @override
  String get timePickerDone => 'Done';

  @override
  String get nextOrderNearby => 'Next order nearby';

  @override
  String nextOrderDistance(int meters) {
    return 'Pickup in $meters m';
  }

  @override
  String get nextOrderOwnPrice => 'Offer a price';

  @override
  String get nextOrderAccept => 'Accept';

  @override
  String get registerUnexpectedError => 'Could not register. Please try again.';

  @override
  String get driverOrderUpdateFailed =>
      'Could not update the order status. Try again.';

  @override
  String get driverOrderHeading => 'Heading to passenger';

  @override
  String get driverOrderWaiting => 'Waiting for passenger';

  @override
  String get driverOrderInProgress => 'Trip in progress';

  @override
  String get driverOrderAtPickup => 'At pickup';

  @override
  String get driverOrderStart => 'Start trip';

  @override
  String get driverOrderFinish => 'Complete trip';

  @override
  String get driverOrderCost => 'Price:';

  @override
  String bookingSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats',
      one: '$count seat',
    );
    return '$_temp0';
  }

  @override
  String get navContinueToPoint => 'Continue to the point';

  @override
  String get navArrived => 'You have arrived';

  @override
  String get navDepart => 'Start driving';

  @override
  String get navExitRoundabout => 'Exit the roundabout';

  @override
  String get navEnterRoundabout => 'Enter the roundabout';

  @override
  String navRoundaboutExit(int exitNumber) {
    return 'At the roundabout, take exit $exitNumber';
  }

  @override
  String get navUTurn => 'Make a U-turn';

  @override
  String get navKeepLeft => 'Keep left';

  @override
  String get navKeepRight => 'Keep right';

  @override
  String get navContinue => 'Continue';

  @override
  String get navMergeLeft => 'Merge from the left';

  @override
  String get navMergeRight => 'Merge from the right';

  @override
  String get navMerge => 'Merge';

  @override
  String get navOnRamp => 'Take the ramp';

  @override
  String get navOffRamp => 'Take the exit ramp';

  @override
  String get navStraight => 'Continue straight';

  @override
  String get navTurnSharpLeft => 'Turn sharp left';

  @override
  String get navTurnSharpRight => 'Turn sharp right';

  @override
  String get navTurnSlightLeft => 'Turn slightly left';

  @override
  String get navTurnSlightRight => 'Turn slightly right';

  @override
  String get navTurnLeft => 'Turn left';

  @override
  String get navTurnRight => 'Turn right';

  @override
  String navDistanceMeters(int value) {
    return 'In $value m';
  }

  @override
  String navDistanceKilometers(String value) {
    return 'In $value km';
  }

  @override
  String navMetersShort(int value) {
    return '$value m';
  }

  @override
  String navKilometersShort(String value) {
    return '$value km';
  }

  @override
  String navMinutesShort(int value) {
    return '$value min';
  }

  @override
  String navHoursMinutesShort(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String navRemaining(String summary) {
    return 'Remaining: $summary';
  }

  @override
  String get mapAddAddress => 'Add address';

  @override
  String mapStopNumber(int number) {
    return 'Stop $number';
  }

  @override
  String get mapFinalDestination => 'Final destination';

  @override
  String get mapRemoveStop => 'Remove stop';

  @override
  String get mapChooseAllStops => 'Choose an address for every stop.';

  @override
  String get driverMapNextStop => 'Next stop';

  @override
  String get intercityOpenChat => 'Open chat';

  @override
  String get intercityWhatsApp => 'Message on WhatsApp';

  @override
  String get intercityWhatsAppUnavailable => 'Could not open WhatsApp.';

  @override
  String get intercityNavigationUnavailable =>
      'This ride has no destination coordinates.';

  @override
  String get intercityNavigationTitle => 'Intercity navigation';

  @override
  String get intercityNextPoint => 'Next point';

  @override
  String get intercityFinishRide => 'Complete ride';

  @override
  String get pushIntercityTripCompleted => 'Intercity ride completed';

  @override
  String get pushIntercityChatMessage => 'New ride message';

  @override
  String get intercityContinueActiveTrip => 'Continue trip';

  @override
  String get intercityMarkPickupReached => 'Passenger picked up';

  @override
  String get intercityPickupReached => 'Passenger already picked up';

  @override
  String get intercityActiveTripUnknown =>
      'Could not check the active trip. Please try again.';

  @override
  String get cityCancelTripTitle => 'Cancel the trip?';

  @override
  String get cityCancelTripWarning =>
      'The trip has already started. Cancel it only if necessary.';

  @override
  String get cityCancelReasonLabel => 'Choose a cancellation reason';

  @override
  String get cityCancelReasonRequired =>
      'Choose a reason for cancelling the trip.';

  @override
  String get cityCancelReasonPlansChanged => 'Plans changed';

  @override
  String get cityCancelReasonCarProblem => 'Problem with the car';

  @override
  String get cityCancelReasonDriverProblem => 'Problem with the driver';

  @override
  String get cityCancelReasonCarBreakdown => 'Car breakdown';

  @override
  String get cityCancelReasonRoadIncident => 'Accident / road conditions';

  @override
  String get cityCancelReasonPassengerRequested =>
      'Passenger requested cancellation';

  @override
  String get cityCancelReasonPassengerProblem => 'Problem with the passenger';

  @override
  String get cityCancelReasonEmergency => 'Emergency';

  @override
  String get cityCancelReasonOther => 'Other reason';

  @override
  String get cityCancelReasonDetails => 'Describe the reason (optional)';

  @override
  String get cityCancelFinalConfirmation =>
      'Confirm cancellation of the started trip?';

  @override
  String get pushCityCancelledByPassenger => 'Order cancelled by passenger';

  @override
  String get pushCityCancelledByDriver => 'Driver cancelled the trip';

  @override
  String get deliveryRouteSection => 'Route';

  @override
  String get deliveryParcelSection => 'Delivery item';

  @override
  String get deliveryContactsSection => 'Contacts';

  @override
  String get deliverySenderSection => 'Sender';

  @override
  String get deliverySenderCurrentUser =>
      'You — the account placing this order';

  @override
  String get deliveryRecipientSection => 'Recipient';

  @override
  String get deliveryAdditionalSection => 'Additional details';

  @override
  String get deliveryDetailsFilled => 'Filled in';

  @override
  String get deliveryPriceSection => 'Delivery price';

  @override
  String get driverWorkCity => 'Work city';

  @override
  String get driverWorkCityChangeFailed =>
      'Could not change the work city. Finish the active trip or try again later.';

  @override
  String get citiesUnavailable =>
      'Could not load the city list. Please try again.';

  @override
  String get termsTitle => 'Terms of Use';

  @override
  String termsBody(String version) {
    return 'Version $version. Before posting messages, reviews, or other content, read the MEKEN terms. Do not post abuse, threats, spam, unlawful, or unsafe content. You can report content or block another user. The full text is kept in the MEKEN documents.';
  }

  @override
  String get termsConfirm => 'I have read and accept the Terms of Use';

  @override
  String get termsAccept => 'Accept';

  @override
  String get termsAcceptFailed =>
      'Could not save your acceptance. Please try again.';

  @override
  String get reportUser => 'Report';

  @override
  String get blockUser => 'Block user';

  @override
  String get blockUserConfirm =>
      'Block this user from future trips and post-trip communication?';

  @override
  String get reportSent => 'Report submitted';

  @override
  String get userBlocked => 'User blocked';

  @override
  String get reportReasonAbuse => 'Abuse';

  @override
  String get reportReasonHarassment => 'Harassment';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonUnsafe => 'Unsafe behavior';

  @override
  String get reportReasonInappropriate => 'Inappropriate content';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get aboutSupportTitle => 'About and support';

  @override
  String get legalTerms => 'Terms of Use';

  @override
  String get legalTermsHint => 'Open the current full text';

  @override
  String get legalPrivacy => 'Privacy Policy';

  @override
  String get legalPrivacyHint => 'How MEKEN handles your data';

  @override
  String get legalAccountDeletion => 'Account deletion';

  @override
  String get legalAccountDeletionHint =>
      'Instructions and public deletion page';

  @override
  String get legalSupport => 'Support';

  @override
  String get legalSupportPending =>
      'Contact details will be published before release';

  @override
  String get legalVersion => 'App version';

  @override
  String get legalOpenFailed => 'Could not open the link';
}
