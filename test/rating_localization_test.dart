import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/services/rating_service.dart';
import 'package:taxi_esil/widgets/rating_dialog.dart';

class _FailingRatingService implements RatingService {
  _FailingRatingService(this.failure);

  final RatingSubmissionFailure? failure;

  @override
  Future<void> submitRating({
    required String orderId,
    required String targetUserId,
    required int score,
    String? comment,
  }) async {
    throw RatingSubmissionException('raw service diagnostic', failure: failure);
  }
}

Future<void> _showRating(
  WidgetTester tester,
  String locale,
  RatingService service, {
  bool ratingDriver = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => RatingDialog(
                orderId: 'order',
                targetUserId: 'target',
                isRatingDriver: ratingDriver,
                ratingService: service,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  for (final (locale, driverTitle, passengerTitle, hint, cancel, submit, failed)
      in [
        (
          'ru',
          'Оцените водителя',
          'Оцените пассажира',
          'Напишите отзыв (необязательно)',
          'Отмена',
          'Отправить',
          'Не удалось отправить оценку. Попробуйте ещё раз.',
        ),
        (
          'kk',
          'Жүргізушіні бағалаңыз',
          'Жолаушыны бағалаңыз',
          'Пікір жазыңыз (міндетті емес)',
          'Болдырмау',
          'Жіберу',
          'Бағаны жіберу мүмкін болмады. Қайталап көріңіз.',
        ),
        (
          'en',
          'Rate your driver',
          'Rate your passenger',
          'Write a review (optional)',
          'Cancel',
          'Submit',
          'Could not submit the rating. Please try again.',
        ),
      ]) {
    testWidgets('rating dialog labels and fallback error in $locale', (
      tester,
    ) async {
      await _showRating(tester, locale, _FailingRatingService(null));
      expect(find.text(driverTitle), findsOneWidget);
      expect(find.text(cancel), findsOneWidget);
      expect(find.text(submit), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('rating_review')))
            .decoration
            ?.hintText,
        hint,
      );
      await tester.tap(find.text(submit));
      await tester.pump();
      expect(find.text(failed), findsOneWidget);
      expect(find.text('raw service diagnostic'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await _showRating(
        tester,
        locale,
        _FailingRatingService(null),
        ratingDriver: false,
      );
      expect(find.text(passengerTitle), findsOneWidget);
      expect(find.byKey(const Key('rating_review')), findsNothing);
    });
  }

  for (final failure in RatingSubmissionFailure.values) {
    testWidgets('rating error $failure uses localized display copy', (
      tester,
    ) async {
      await _showRating(tester, 'en', _FailingRatingService(failure));
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(find.text('raw service diagnostic'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(RatingDialog), findsOneWidget);
    });
  }
}
