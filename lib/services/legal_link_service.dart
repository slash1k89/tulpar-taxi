import 'package:url_launcher/url_launcher.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri);

class LegalLinkService {
  const LegalLinkService({ExternalUriLauncher? launcher})
    : _launcher = launcher ?? _launchExternally;

  final ExternalUriLauncher _launcher;

  Future<bool> openHttps(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'tulpartaxi.kz') {
      return Future.value(false);
    }
    return _launcher(uri);
  }

  Future<bool> openSupportEmail(String email) {
    final normalized = email.trim();
    if (normalized.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      return Future.value(false);
    }
    return _launcher(Uri(scheme: 'mailto', path: normalized));
  }

  static Future<bool> _launchExternally(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
