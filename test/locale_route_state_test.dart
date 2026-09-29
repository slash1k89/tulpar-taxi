import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/main.dart';
import 'package:taxi_esil/services/locale_controller.dart';

void main() {
  for (final stateName in const [
    'login',
    'passenger home',
    'driver idle',
    'active passenger order',
    'active driver order',
  ]) {
    testWidgets('locale change preserves $stateName route and state', (
      tester,
    ) async {
      final language = LocaleController(
        read: () async => 'ru',
        write: (_) async {},
        isAuthenticated: () => false,
        systemLocale: () => const Locale('ru'),
      );
      await language.load();
      final probeKey = GlobalKey<_RouteProbeState>();
      await tester.pumpWidget(
        TaxiApp(
          localeController: language,
          home: _RouteProbe(key: probeKey, stateName: stateName),
        ),
      );
      await tester.pumpAndSettle();
      probeKey.currentState!.operationalValue = 'order-42';

      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Builder(
              builder: (context) => Text(
                '${AppLocalizations.of(context).profileSettingsTitle}-$stateName',
                key: const Key('settings-route'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final routeBefore = ModalRoute.of(
        tester.element(find.byKey(const Key('settings-route'))),
      );

      await language.choose('en');
      await tester.pumpAndSettle();

      final routeAfter = ModalRoute.of(
        tester.element(find.byKey(const Key('settings-route'))),
      );
      expect(routeAfter, same(routeBefore));
      expect(find.text('Profile and settings-$stateName'), findsOneWidget);
      expect(probeKey.currentState, isNotNull);
      expect(probeKey.currentState!.operationalValue, 'order-42');

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(Key('route-$stateName')), findsOneWidget);
      expect(probeKey.currentState!.operationalValue, 'order-42');
      language.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _RouteProbe extends StatefulWidget {
  const _RouteProbe({super.key, required this.stateName});
  final String stateName;

  @override
  State<_RouteProbe> createState() => _RouteProbeState();
}

class _RouteProbeState extends State<_RouteProbe> {
  String operationalValue = 'initial';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Text(widget.stateName, key: Key('route-${widget.stateName}')),
  );
}
