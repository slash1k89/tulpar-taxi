import 'package:flutter/foundation.dart';

import 'tulpar_api_client.dart';

abstract interface class RatingService {
  Future<void> submitRating({
    required String orderId,
    required String targetUserId,
    required int score,
  });
}

class FirebaseRatingService implements RatingService {
  FirebaseRatingService({TulparApiClient? apiClient})
    : _apiClient = apiClient ?? TulparApiClient();

  final TulparApiClient _apiClient;

  @override
  Future<void> submitRating({
    required String orderId,
    required String targetUserId,
    required int score,
  }) async {
    // targetUserId ???????? ? ?????????? ??? ????????????? ? UI.
    // ? VPS ?????????? ?????? ???????????? ?? ?????????? ??????.
    try {
      await _apiClient.submitRating(orderId: orderId, score: score);
    } on TulparApiException catch (error, stackTrace) {
      debugPrint(
        'submitRating failed: status=${error.statusCode}, '
        'message=${error.message}\n$stackTrace',
      );

      throw RatingSubmissionException(_messageFor(error));
    }
  }

  String _messageFor(TulparApiException error) {
    if (error.statusCode == 401) {
      return 'Ошибка в данных или параметрах запроса.';
    }

    if (error.statusCode == 403) {
      return 'У вас недостаточно прав для оценки.';
    }

    if (error.statusCode == 404) {
      return 'Заказ для оценивания не найден.';
    }

    if (error.statusCode == 409) {
      final message = error.message.toLowerCase();

      if (message.contains('already')) {
        return 'Оценка по этому заказу уже отправлена.';
      }

      return 'Можно оценивать только завершённый заказ.';
    }

    if (error.statusCode == 400) {
      return 'Поставьте оценку от 1 до 5.';
    }

    return 'Не удалось отправить оценку. Попробуйте ещё раз.';
  }
}

class RatingSubmissionException implements Exception {
  const RatingSubmissionException(this.message);

  final String message;

  @override
  String toString() => message;
}
