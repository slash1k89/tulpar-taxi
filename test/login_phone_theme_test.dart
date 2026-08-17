import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/screens/auth/login_screen.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('phone number is visible in ${brightness.name} theme', (
      tester,
    ) async {
      final colorScheme = ColorScheme.fromSeed(
        seedColor: Colors.amber,
        brightness: brightness,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: colorScheme),
          home: const LoginScreen(),
        ),
      );

      final phoneFinder = find.byKey(const Key('login_phone_field'));
      await tester.enterText(phoneFinder, '7001234567');
      await tester.pump();

      final phoneField = tester.widget<TextField>(phoneFinder);
      final decoration = phoneField.decoration!;
      expect(phoneField.style?.color, colorScheme.onSurface);
      expect(phoneField.cursorColor, colorScheme.primary);
      expect(phoneField.cursorErrorColor, colorScheme.error);
      expect(decoration.labelStyle?.color, colorScheme.onSurfaceVariant);
      expect(decoration.hintStyle?.color, colorScheme.onSurfaceVariant);
      expect(decoration.errorStyle?.color, colorScheme.error);
      expect((decoration.prefixIcon as Icon).color, colorScheme.primary);
      expect(phoneField.controller?.text, isNotEmpty);
    });
  }
}
