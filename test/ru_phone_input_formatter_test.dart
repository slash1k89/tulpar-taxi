import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/utils/formatters.dart';

void main() {
  group('RuPhoneInputFormatter', () {
    test('manual input adds exactly one user digit per edit', () {
      final formatter = RuPhoneInputFormatter();
      var value = TextEditingValue.empty;

      for (final digit in '7771234567'.split('')) {
        final raw = value.text + digit;
        value = formatter.formatEditUpdate(
          value,
          TextEditingValue(
            text: raw,
            selection: TextSelection.collapsed(offset: raw.length),
          ),
        );
      }

      expect(value.text, '+7 (777) 123-45-67');
      expect(normalizeRuPhone(value.text), '+77771234567');

      final rawAfterBackspace = value.text.substring(0, value.text.length - 1);
      value = formatter.formatEditUpdate(
        value,
        TextEditingValue(
          text: rawAfterBackspace,
          selection: TextSelection.collapsed(offset: rawAfterBackspace.length),
        ),
      );
      expect(value.text, '+7 (777) 123-45-6');
    });

    for (final pasted in <String>[
      '+77771234567',
      '77771234567',
      '87771234567',
      '7771234567',
    ]) {
      test('normalizes pasted $pasted', () {
        final formatter = RuPhoneInputFormatter();
        final value = formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: pasted,
            selection: TextSelection.collapsed(offset: pasted.length),
          ),
        );

        expect(value.text, '+7 (777) 123-45-67');
        expect(normalizeRuPhone(value.text), '+77771234567');
      });
    }
  });
}
