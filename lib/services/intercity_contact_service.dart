import 'package:url_launcher/url_launcher.dart';

String? normalizeWhatsAppPhone(String? value) {
  final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
  if (digits.length < 10 || digits.length > 15) return null;
  return digits;
}

Uri? intercityWhatsAppUri(String? phone) {
  final normalized = normalizeWhatsAppPhone(phone);
  return normalized == null ? null : Uri.https('wa.me', '/$normalized');
}

Future<bool> openIntercityWhatsApp(String? phone) async {
  final uri = intercityWhatsAppUri(phone);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
