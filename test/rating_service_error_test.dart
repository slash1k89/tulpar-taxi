import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/services/rating_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';

void main() {
  for (final (status, body, expected) in [
    (401, '{"error":"invalid"}', RatingSubmissionFailure.invalidRequest),
    (403, '{"error":"forbidden"}', RatingSubmissionFailure.forbidden),
    (404, '{"error":"missing"}', RatingSubmissionFailure.orderMissing),
    (409, '{"error":"already rated"}', RatingSubmissionFailure.alreadySent),
    (409, '{"error":"not completed"}', RatingSubmissionFailure.notCompleted),
    (400, '{"error":"invalid score"}', RatingSubmissionFailure.invalidScore),
    (500, '{"error":"failed"}', RatingSubmissionFailure.failed),
  ]) {
    test(
      'rating service preserves structured failure for HTTP $status: $expected',
      () async {
        final api = TulparApiClient(
          tokenProvider: () async => 'test-token',
          client: MockClient((_) async => http.Response(body, status)),
        );
        final service = FirebaseRatingService(apiClient: api);

        await expectLater(
          service.submitRating(
            orderId: 'order',
            targetUserId: 'target',
            score: 5,
          ),
          throwsA(
            isA<RatingSubmissionException>().having(
              (error) => error.failure,
              'failure',
              expected,
            ),
          ),
        );
        api.close();
      },
    );
  }
}
