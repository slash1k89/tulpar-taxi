import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/widgets/tulpar_date_picker.dart';

void main() {
  for (final (code, month, done) in [
    ('ru', 'феврал', 'Готово'),
    ('kk', 'ақпан', 'Дайын'),
    ('en', 'February', 'Done'),
  ]) {
    testWidgets('calendar month and action use $code', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: Locale(code),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showTulparDatePicker(
              context: context,
              initialDate: DateTime(2028, 2, 10),
              firstDate: DateTime(2028, 1, 1),
              lastDate: DateTime(2028, 12, 31),
            ),
            child: const Text('open'),
          ),
        )),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining(month, findRichText: true), findsWidgets);
      expect(find.text(done), findsOneWidget);
    });
  }
}
