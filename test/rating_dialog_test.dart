import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/rating_service.dart';
import 'package:taxi_esil/widgets/rating_dialog.dart';

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

  testWidgets('rating error is readable and keeps dialog open', (tester) async {
    final service = _FakeRatingService(
      error: const RatingSubmissionException(
        'Р В Р’В Р РЋРІР‚С”Р В Р Р‹Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’ВµР В Р’В Р В РІР‚В¦Р В Р’В Р РЋРІР‚СњР В Р’В Р вЂ™Р’В° Р В Р’В Р вЂ™Р’В·Р В Р’В Р вЂ™Р’В° Р В Р Р‹Р В Р Р‰Р В Р Р‹Р Р†Р вЂљРЎв„ўР В Р Р‹Р РЋРІР‚Сљ Р В Р’В Р РЋРІР‚вЂќР В Р’В Р РЋРІР‚СћР В Р’В Р вЂ™Р’ВµР В Р’В Р вЂ™Р’В·Р В Р’В Р СћРІР‚ВР В Р’В Р РЋРІР‚СњР В Р Р‹Р РЋРІР‚Сљ Р В Р Р‹Р РЋРІР‚СљР В Р’В Р вЂ™Р’В¶Р В Р’В Р вЂ™Р’Вµ Р В Р’В Р РЋРІР‚СћР В Р Р‹Р Р†Р вЂљРЎв„ўР В Р’В Р РЋРІР‚вЂќР В Р Р‹Р В РІР‚С™Р В Р’В Р вЂ™Р’В°Р В Р’В Р В РІР‚В Р В Р’В Р вЂ™Р’В»Р В Р’В Р вЂ™Р’ВµР В Р’В Р В РІР‚В¦Р В Р’В Р вЂ™Р’В°.',
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
    expect(
      find.text(
        'Р В Р’В Р РЋРІР‚С”Р В Р Р‹Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’ВµР В Р’В Р В РІР‚В¦Р В Р’В Р РЋРІР‚СњР В Р’В Р вЂ™Р’В° Р В Р’В Р вЂ™Р’В·Р В Р’В Р вЂ™Р’В° Р В Р Р‹Р В Р Р‰Р В Р Р‹Р Р†Р вЂљРЎв„ўР В Р Р‹Р РЋРІР‚Сљ Р В Р’В Р РЋРІР‚вЂќР В Р’В Р РЋРІР‚СћР В Р’В Р вЂ™Р’ВµР В Р’В Р вЂ™Р’В·Р В Р’В Р СћРІР‚ВР В Р’В Р РЋРІР‚СњР В Р Р‹Р РЋРІР‚Сљ Р В Р Р‹Р РЋРІР‚СљР В Р’В Р вЂ™Р’В¶Р В Р’В Р вЂ™Р’Вµ Р В Р’В Р РЋРІР‚СћР В Р Р‹Р Р†Р вЂљРЎв„ўР В Р’В Р РЋРІР‚вЂќР В Р Р‹Р В РІР‚С™Р В Р’В Р вЂ™Р’В°Р В Р’В Р В РІР‚В Р В Р’В Р вЂ™Р’В»Р В Р’В Р вЂ™Р’ВµР В Р’В Р В РІР‚В¦Р В Р’В Р вЂ™Р’В°.',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _openDialog(
  WidgetTester tester,
  RatingService ratingService,
) async {
  await tester.pumpWidget(
    MaterialApp(
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
