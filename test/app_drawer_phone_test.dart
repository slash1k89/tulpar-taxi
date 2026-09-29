import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/widgets/app_drawer.dart';

void main() {
  testWidgets('drawer shows formatted phone and never exposes user UUID', (
    tester,
  ) async {
    const userId = '029e3102-d23e-4d7a-95ea-29962dd0d6d6';

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(),
          drawer: AppDrawer(
            mode: AppMode.passenger,
            phoneLoader: () async => '+77011234567',
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('+7 701 123 45 67'), findsOneWidget);
    expect(find.text(userId), findsNothing);
  });

  testWidgets('drawer keeps user identity blank while phone is unavailable', (
    tester,
  ) async {
    const userId = '029e3102-d23e-4d7a-95ea-29962dd0d6d6';

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(),
          drawer: AppDrawer(
            mode: AppMode.passenger,
            phoneLoader: () async => null,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(
      find.byKey(const Key('drawer_user_label')),
    );
    expect(label.data, isEmpty);
    expect(find.text(userId), findsNothing);
  });
}
