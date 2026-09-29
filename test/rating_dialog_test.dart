import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/rating_service.dart';
import 'package:taxi_esil/widgets/rating_dialog.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('rating dialog submits through service only once', (
    tester,
  ) async {
    final service = _FakeRatingService(waitForCompletion: true);
    await _openDialog(tester, service);

    await tester.tap(
      find.descendant(
        of: find.byType(RatingDialog),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(RatingDialog),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.pump();

    expect(service.calls, 1);
    expect(service.orderId, 'order-1');
    expect(service.targetUserId, 'driver-1');
    expect(service.score, 5);

    service.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('rating error is localized and keeps dialog open', (
    tester,
  ) async {
    final service = _FakeRatingService(
      error: const RatingSubmissionException(
        'raw service diagnostic',
        failure: RatingSubmissionFailure.forbidden,
      ),
    );
    await _openDialog(tester, service);

    await tester.tap(
      find.descendant(
        of: find.byType(RatingDialog),
        matching: find.byType(ElevatedButton),
      ),
    );
    await tester.pump();

    expect(find.byType(RatingDialog), findsOneWidget);
    expect(find.text('У вас недостаточно прав для оценки.'), findsOneWidget);
    expect(find.text('raw service diagnostic'), findsNothing);
  });

  for (final (code, title, hint) in [
    ('ru', 'Оцените водителя', 'Напишите отзыв (необязательно)'),
    ('kk', 'Жүргізушіні бағалаңыз', 'Пікір жазыңыз (міндетті емес)'),
    ('en', 'Rate your driver', 'Write a review (optional)'),
  ]) {
    testWidgets('rating dialog uses $code', (tester) async {
      await _openDialog(tester, _FakeRatingService(), localeCode: code);
      expect(find.text(title), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('rating_review')))
            .decoration
            ?.hintText,
        hint,
      );
    });
  }
}

Future<void> _openDialog(
  WidgetTester tester,
  RatingService ratingService, {
  String localeCode = 'ru',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(localeCode),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => RatingDialog(
                targetUserId: 'driver-1',
                orderId: 'order-1',
                isRatingDriver: true,
                ratingService: ratingService,
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

class _FakeRatingService implements RatingService {
  _FakeRatingService({this.waitForCompletion = false, this.error});

  final bool waitForCompletion;
  final RatingSubmissionException? error;
  final Completer<void> _completer = Completer<void>();
  int calls = 0;
  String? orderId;
  String? targetUserId;
  int? score;

  @override
  Future<void> submitRating({
    required String orderId,
    required String targetUserId,
    required int score,
    String? comment,
  }) async {
    calls++;
    this.orderId = orderId;
    this.targetUserId = targetUserId;
    this.score = score;
    if (error != null) throw error!;
    if (waitForCompletion) await _completer.future;
  }

  void complete() => _completer.complete();
}
