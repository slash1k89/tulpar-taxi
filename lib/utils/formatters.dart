import 'package:flutter/services.dart';

class KazakhPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');

    final StringBuffer result = StringBuffer();
    int index = (text.startsWith('7') || text.startsWith('8')) ? 1 : 0;

    result.write('+7 (');

    if (text.length > index) {
      if (text.length - index <= 3) {
        result.write(text.substring(index));
        return TextEditingValue(text: result.toString(), selection: TextSelection.collapsed(offset: result.length));
      } else {
        result.write(text.substring(index, index + 3));
        result.write(') ');
        index += 3;
      }
    }
    if (text.length > index) {
      if (text.length - index <= 3) {
        result.write(text.substring(index));
        return TextEditingValue(text: result.toString(), selection: TextSelection.collapsed(offset: result.length));
      } else {
        result.write(text.substring(index, index + 3));
        result.write('-');
        index += 3;
      }
    }
    if (text.length > index) {
      if (text.length - index <= 2) {
        result.write(text.substring(index));
        return TextEditingValue(text: result.toString(), selection: TextSelection.collapsed(offset: result.length));
      } else {
        result.write(text.substring(index, index + 2));
        result.write('-');
        index += 2;
      }
    }
    if (text.length > index) {
      final end = (text.length - index > 2) ? index + 2 : text.length;
      result.write(text.substring(index, end));
    }

    return TextEditingValue(text: result.toString(), selection: TextSelection.collapsed(offset: result.length));
  }
}