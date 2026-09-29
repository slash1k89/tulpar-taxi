import 'locale_controller.dart';

const _voiceRoot = 'audio/navigation';

const voiceAssetFileNames = <String>{
  'dist_50m.mp3',
  'dist_100m.mp3',
  'dist_200m.mp3',
  'dist_300m.mp3',
  'dist_500m.mp3',
  'dist_800m.mp3',
  'dist_1km.mp3',
  'dist_2km.mp3',
  'dist_3km.mp3',
  'driver_approaching.mp3',
  'message_new.mp3',
  'order_arrived.mp3',
  'order_cancelled.mp3',
  'order_complete.mp3',
  'order_new.mp3',
  'order_waiting.mp3',
  'roundabout_enter.mp3',
  'roundabout_exit_1.mp3',
  'roundabout_exit_2.mp3',
  'roundabout_exit_3.mp3',
  'roundabout_exit_4.mp3',
  'route_created.mp3',
  'route_finish.mp3',
  'route_recalculating.mp3',
  'turn_around.mp3',
  'turn_keep_left.mp3',
  'turn_keep_right.mp3',
  'turn_left.mp3',
  'turn_right.mp3',
  'turn_straight.mp3',
};

String voiceAsset(String fileName, {String? languageCode}) {
  if (!voiceAssetFileNames.contains(fileName)) {
    throw ArgumentError.value(fileName, 'fileName', 'Unknown voice asset');
  }
  final requested =
      languageCode ?? appLocaleController.effectiveLocale.languageCode;
  final language = const {'ru', 'kk', 'en'}.contains(requested)
      ? requested
      : 'ru';
  return '$_voiceRoot/$language/$fileName';
}

String localizedVoiceAssetPath(String logicalPath, {String? languageCode}) {
  const legacyPrefix = '$_voiceRoot/';
  if (!logicalPath.startsWith(legacyPrefix)) return logicalPath;
  if (const ['ru', 'kk', 'en'].any(
    (language) => logicalPath.startsWith('$legacyPrefix$language/'),
  )) {
    return logicalPath;
  }
  final fileName = logicalPath.substring(logicalPath.lastIndexOf('/') + 1);
  if (!voiceAssetFileNames.contains(fileName)) return logicalPath;
  return voiceAsset(fileName, languageCode: languageCode);
}
