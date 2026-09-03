import 'package:flutter/services.dart';

String normalizeRuPhone(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('7') || digits.startsWith('8')) {
    digits = digits.substring(1);
  }
  if (digits.length > 10) digits = digits.substring(0, 10);
  return digits.isEmpty ? '' : '+7$digits';
}

bool isCompleteRuPhone(String value) =>
    normalizeRuPhone(value).replaceAll(RegExp(r'\D'), '').length == 11;

String formatRuPhoneForDisplay(String value) {
  final normalized = normalizeRuPhone(value);
  final digits = normalized.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 11) return '';
  return '+7 ${digits.substring(1, 4)} ${digits.substring(4, 7)} '
      '${digits.substring(7, 9)} ${digits.substring(9, 11)}';
}

class RuPhoneInputFormatter extends TextInputFormatter {
  String _subscriberDigits(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    final hasExplicitCountryPrefix = value.trimLeft().startsWith('+7');
    final hasFullNationalPrefix =
        digits.length > 10 &&
        (digits.startsWith('7') || digits.startsWith('8'));
    if (hasExplicitCountryPrefix || hasFullNationalPrefix) {
      digits = digits.substring(1);
    }
    return digits.length > 10 ? digits.substring(0, 10) : digits;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final oldDigits = _subscriberDigits(oldValue.text);
    var newDigits = _subscriberDigits(newValue.text);
    if (newValue.text.length < oldValue.text.length && oldDigits == newDigits) {
      if (newDigits.isNotEmpty) {
        newDigits = newDigits.substring(0, newDigits.length - 1);
      }
    }
    if (newDigits.isEmpty) return TextEditingValue.empty;
    final buffer = StringBuffer('+7 ');
    if (newDigits.isNotEmpty) {
      buffer
        ..write('(')
        ..write(
          newDigits.substring(0, newDigits.length >= 3 ? 3 : newDigits.length),
        );
      if (newDigits.length >= 3) {
        buffer
          ..write(') ')
          ..write(
            newDigits.substring(
              3,
              newDigits.length >= 6 ? 6 : newDigits.length,
            ),
          );
      }
      if (newDigits.length >= 6) {
        buffer
          ..write('-')
          ..write(
            newDigits.substring(
              6,
              newDigits.length >= 8 ? 8 : newDigits.length,
            ),
          );
      }
      if (newDigits.length >= 8) {
        buffer
          ..write('-')
          ..write(
            newDigits.substring(
              8,
              newDigits.length >= 10 ? 10 : newDigits.length,
            ),
          );
      }
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
