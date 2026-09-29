import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/widgets/rating_dialog.dart';
import 'package:taxi_esil/services/rating_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';
import 'package:taxi_esil/screens/profile/driver_public_profile_screen.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';

Future<void> _openRating(
  WidgetTester tester,
  _Rating service, {
  bool driver = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
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
                isRatingDriver: driver,
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
  for (final width in [280.0, 320.0, 360.0]) {
    for (final driver in [true, false]) {
      testWidgets(
        'rating $driver at width $width: five accessible 48px stars without overflow',
        (tester) async {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final service = _Rating();
          await _openRating(tester, service, driver: driver);
          expect(tester.takeException(), isNull);
          final dialog = tester.getRect(find.byType(AlertDialog));
          for (var i = 1; i <= 5; i++) {
            final star = find.byKey(ValueKey('rating_star_$i'));
            final rect = tester.getRect(star);
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(dialog.contains(rect.center), isTrue);
            expect(rect.right, lessThanOrEqualTo(dialog.right));
            await tester.tap(star);
            await tester.pump();
          }
          expect(
            find.byKey(const Key('rating_review')),
            driver ? findsOneWidget : findsNothing,
          );
          await tester.ensureVisible(find.text('Отправить'));
          await tester.tap(find.text('Отправить'));
          await tester.pumpAndSettle();
          expect(service.score, 5);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('optional review trimmed and submitted together with rating', (
    tester,
  ) async {
    final service = _Rating();
    await _openRating(tester, service);
    await tester.enterText(
      find.byKey(const Key('rating_review')),
      '  Чистая машина  ',
    );
    await tester.tap(find.byKey(const ValueKey('rating_star_4')));
    await tester.tap(find.text('Отправить'));
    await tester.pumpAndSettle();
    expect(service.comment, 'Чистая машина');
    expect(service.score, 4);
  });

  testWidgets('review input limits length to 500', (tester) async {
    await _openRating(tester, _Rating());
    await tester.enterText(find.byKey(const Key('rating_review')), 'я' * 510);
    final input = tester.widget<TextField>(
      find.byKey(const Key('rating_review')),
    );
    expect(input.controller!.text.length, 500);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'public driver profile renders rating count car and long review on narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(280, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DriverPublicProfileScreen(
            orderId: 'order',
            profileLoader: () async => {
              'name': 'Иван',
              'carModel': 'ВАЗ 2114',
              'carColor': 'Черный',
              'carNumber': '908ALI03',
              'averageRating': 4.8,
              'ratingsCount': 37,
              'reviews': [
                {
                  'score': 5,
                  'comment': 'Очень длинный отзыв ' * 25,
                  'createdAt': '2026-08-31T12:00:00Z',
                },
              ],
              'phone': 'PRIVATE',
              'user_id': 'PRIVATE',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('★ 4.8'), findsOneWidget);
      expect(find.text('37 оценок'), findsOneWidget);
      expect(find.text('ВАЗ 2114'), findsOneWidget);
      expect(find.text('Черный · 908ALI03'), findsOneWidget);
      expect(find.textContaining('Очень длинный отзыв'), findsOneWidget);
      expect(find.textContaining('PRIVATE'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'public driver profile handles absent rating and empty/NULL comments',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DriverPublicProfileScreen(
            orderId: 'order',
            profileLoader: () async => {
              'averageRating': null,
              'ratingsCount': 0,
              'reviews': [
                {'score': 5, 'comment': null},
                {'score': 4, 'comment': ' '},
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Нет оценок'), findsOneWidget);
      expect(find.text('Отзывов пока нет'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (code, noRatings, noReviews) in [
    ('kk', 'Бағалар жоқ', 'Әзірге пікірлер жоқ'),
    ('en', 'No ratings', 'No reviews yet'),
  ]) {
    testWidgets('public driver profile empty state uses $code', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: Locale(code),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DriverPublicProfileScreen(
          orderId: 'order',
          profileLoader: () async => {'ratingsCount': 0, 'reviews': []},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(noRatings), findsOneWidget);
      expect(find.text(noReviews), findsOneWidget);
    });
  }

  test(
    'API sends optional review without client driver identity and uses order-scoped profile',
    () async {
      final api = TulparApiClient(
        tokenProvider: () async => 'test-token',
        client: MockClient((req) async {
          expect(req.headers['Authorization'], 'Bearer test-token');
          if (req.method == 'POST') {
            expect(req.url.path, '/api/orders/order/rating');
            expect(jsonDecode(req.body), {'score': 4, 'comment': 'Хорошо'});
            return http.Response('{}', 201);
          }
          expect(req.url.path, '/api/orders/order/driver-profile');
          return http.Response('{"averageRating":4.8,"ratingsCount":37}', 200);
        }),
      );
      await api.submitRating(orderId: 'order', score: 4, comment: ' Хорошо ');
      expect((await api.getAssignedDriverProfile('order'))['ratingsCount'], 37);
      api.close();
    },
  );
}

class _Rating implements RatingService {
  int? score;
  String? comment;
  @override
  Future<void> submitRating({
    required String orderId,
    required String targetUserId,
    required int score,
    String? comment,
  }) async {
    this.score = score;
    this.comment = comment;
  }
}
