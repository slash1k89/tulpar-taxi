import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/active_order_service.dart';
import '../../services/tulpar_auth_session.dart';
import '../../services/terms_acceptance_service.dart';
import '../../services/locale_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../legal/about_support_screen.dart';
import '../../utils/formatters.dart';
import '../driver/driver_map_screen.dart';
import '../map/map_screen.dart';
import '../map/order_tracking_screen.dart';

enum _LoginStep { login, verificationPhone, code, password }

enum _PasswordPurpose { setup, reset }

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.authController,
    this.localeController,
    this.activeOrderLoader,
  });

  final TulparAuthController? authController;
  final LocaleController? localeController;
  final Future<ActiveOrder?> Function()? activeOrderLoader;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final TulparAuthController _auth;
  LocaleController get _language =>
      widget.localeController ?? appLocaleController;
  _LoginStep _step = _LoginStep.login;
  _PasswordPurpose? _purpose;
  String? _challengeId;
  String? _verificationToken;
  String? _phone;
  bool _isLoading = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _auth = widget.authController ?? TulparAuthController.instance;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _beginVerification(_PasswordPurpose purpose) {
    if (_isLoading) return;
    setState(() {
      _purpose = purpose;
      _step = _LoginStep.verificationPhone;
      _challengeId = null;
      _verificationToken = null;
      _codeController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  void _backToLogin() {
    _resendTimer?.cancel();
    setState(() {
      _step = _LoginStep.login;
      _purpose = null;
      _challengeId = null;
      _verificationToken = null;
      _resendSeconds = 0;
      _codeController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context);
    if (!isCompleteRuPhone(_phoneController.text)) {
      _showError(l10n.invalidPhone);
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showError(l10n.enterPassword);
      return;
    }
    await _run(() async {
      await _auth.loginWithPassword(
        phone: normalizeRuPhone(_phoneController.text),
        password: _passwordController.text,
      );
      if (!mounted) return;
      unawaited(_language.syncIfAuthenticated());
      await _continueToApp();
    });
  }

  Future<void> _requestCode() async {
    if (!isCompleteRuPhone(_phoneController.text)) {
      _showError(AppLocalizations.of(context).invalidPhone);
      return;
    }
    final phone = normalizeRuPhone(_phoneController.text);
    await _run(() async {
      final challenge = await _auth.requestFlashCall(
        phone: phone,
        purpose: _purpose!.name,
      );
      if (!mounted) return;
      setState(() {
        _phone = phone;
        _challengeId = challenge.challengeId;
        _step = _LoginStep.code;
        _codeController.clear();
        _resendSeconds = challenge.resendAfter;
      });
      _startCountdown();
    });
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      _showError(AppLocalizations.of(context).invalidCode);
      return;
    }
    await _run(() async {
      final result = await _auth.verifyPasswordFlashCall(
        challengeId: _challengeId!,
        phone: _phone!,
        code: code,
        purpose: _purpose!.name,
      );
      if (!mounted) return;
      setState(() {
        _verificationToken = result.verificationToken;
        _step = _LoginStep.password;
      });
    });
  }

  Future<void> _setPassword() async {
    final l10n = AppLocalizations.of(context);
    final password = _passwordController.text;
    if (password.length < 8 || password.length > 128) {
      _showError(l10n.authPasswordTooShort);
      return;
    }
    if (password != _confirmPasswordController.text) {
      _showError(l10n.passwordMismatch);
      return;
    }
    await _run(() async {
      await _auth.setVerifiedPassword(
        verificationToken: _verificationToken!,
        password: password,
        purpose: _purpose!.name,
      );
      if (!mounted) return;
      unawaited(_language.syncIfAuthenticated());
      await _continueToApp();
    });
  }

  Future<void> _continueToApp() async {
    if (!await TermsAcceptanceService().ensureAccepted(context) || !mounted) {
      return;
    }
    final activeOrder =
        await (widget.activeOrderLoader?.call() ??
            ActiveOrderService().findCurrentOrder());
    if (!mounted) return;
    final Widget screen;
    if (activeOrder == null) {
      screen = const MapScreen();
    } else if (activeOrder.isDriver) {
      screen = DriverMapScreen(
        orderId: activeOrder.orderId,
        orderData: activeOrder.data,
      );
    } else {
      screen = OrderTrackingScreen(
        orderId: activeOrder.orderId,
        initialOrderData: activeOrder.data,
      );
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => screen),
      (_) => false,
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await action();
    } on TulparAuthException catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _showError(switch (error.code) {
        'resend_cooldown' => l10n.resendCooldown,
        'invalid_phone' => l10n.checkPhone,
        'invalid_verification' => l10n.invalidVerification,
        'invalid_credentials' => l10n.authInvalidCredentials,
        'invalid_password' => l10n.authPasswordTooShort,
        'password_already_set' => l10n.authPasswordAlreadySet,
        'verification_required' => l10n.authVerificationRequired,
        _ => l10n.loginFailed,
      });
    } on TimeoutException {
      if (mounted) _showError(AppLocalizations.of(context).serverTimeout);
    } catch (_) {
      if (mounted) _showError(AppLocalizations.of(context).loginFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCountdown() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/meken_logo_transparent.png',
                        height: 108,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.local_taxi,
                          size: 110,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(switch (_step) {
                        _LoginStep.login => l10n.loginTitle,
                        _LoginStep.verificationPhone =>
                          _purpose == _PasswordPurpose.setup
                              ? l10n.registerTitle
                              : l10n.authResetPasswordTitle,
                        _LoginStep.code => l10n.verificationTitle,
                        _LoginStep.password =>
                          _purpose == _PasswordPurpose.setup
                              ? l10n.authCreatePasswordTitle
                              : l10n.authResetPasswordTitle,
                      }, style: Theme.of(context).textTheme.headlineSmall),
                      if (_step == _LoginStep.login)
                        const SizedBox(height: 24)
                      else ...[
                        const SizedBox(height: 12),
                        Text(
                          switch (_step) {
                            _LoginStep.verificationPhone =>
                              l10n.authVerificationPhoneHint,
                            _LoginStep.code => l10n.codeHint,
                            _LoginStep.password => l10n.passwordLabel,
                            _LoginStep.login => '',
                          },
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 28),
                      ],
                      if (_step == _LoginStep.login ||
                          _step == _LoginStep.verificationPhone)
                        _phoneField(colors),
                      if (_step == _LoginStep.code) _codeField(colors),
                      if (_step == _LoginStep.login ||
                          _step == _LoginStep.password)
                        _passwordField(colors),
                      if (_step == _LoginStep.password) ...[
                        const SizedBox(height: 14),
                        _confirmPasswordField(colors),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          key: const Key('auth_primary_button'),
                          onPressed: _isLoading
                              ? null
                              : switch (_step) {
                                  _LoginStep.login => _login,
                                  _LoginStep.verificationPhone => _requestCode,
                                  _LoginStep.code => _verifyCode,
                                  _LoginStep.password => _setPassword,
                                },
                          child: _isLoading
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(switch (_step) {
                                  _LoginStep.login => l10n.authSignIn,
                                  _LoginStep.verificationPhone =>
                                    l10n.requestCode,
                                  _LoginStep.code => l10n.confirm,
                                  _LoginStep.password => l10n.continueLabel,
                                }),
                        ),
                      ),
                      if (_step == _LoginStep.login) ...[
                        TextButton(
                          key: const Key('forgot_password_button'),
                          onPressed: _isLoading
                              ? null
                              : () =>
                                    _beginVerification(_PasswordPurpose.reset),
                          child: Text(l10n.authForgotPassword),
                        ),
                        TextButton(
                          key: const Key('register_button'),
                          onPressed: _isLoading
                              ? null
                              : () =>
                                    _beginVerification(_PasswordPurpose.setup),
                          child: Text(l10n.registerButton),
                        ),
                        TextButton.icon(
                          key: const Key('prelogin_legal_links'),
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const AboutSupportScreen(),
                                  ),
                                ),
                          icon: const Icon(Icons.privacy_tip_outlined),
                          label: Text(l10n.aboutSupportTitle),
                        ),
                      ] else if (_step != _LoginStep.login)
                        TextButton(
                          key: const Key('auth_back_to_login'),
                          onPressed: _isLoading ? null : _backToLogin,
                          child: Text(l10n.authBackToLogin),
                        ),
                      if (_step == _LoginStep.code) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          key: const Key('flash_call_resend_button'),
                          onPressed: _isLoading || _resendSeconds > 0
                              ? null
                              : _requestCode,
                          child: Text(
                            _resendSeconds > 0
                                ? l10n.resendIn(_resendSeconds)
                                : l10n.resend,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 16,
              child: PopupMenuButton<String>(
                key: const Key('language_switcher'),
                tooltip: l10n.chooseLanguage,
                onSelected: (code) => unawaited(_language.choose(code)),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    key: Key('language_option_ru'),
                    value: 'ru',
                    child: Text('Русский'),
                  ),
                  PopupMenuItem(
                    key: Key('language_option_kk'),
                    value: 'kk',
                    child: Text('Қазақша'),
                  ),
                  PopupMenuItem(
                    key: Key('language_option_en'),
                    value: 'en',
                    child: Text('English'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language, size: 18),
                      const SizedBox(width: 6),
                      Text(switch (Localizations.localeOf(
                        context,
                      ).languageCode) {
                        'kk' => 'ҚАЗ',
                        'en' => 'EN',
                        _ => 'RU',
                      }, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phoneField(ColorScheme colors) => TextField(
    key: const Key('login_phone_field'),
    controller: _phoneController,
    keyboardType: TextInputType.phone,
    inputFormatters: [RuPhoneInputFormatter()],
    style: TextStyle(color: colors.onSurface),
    cursorColor: colors.primary,
    cursorErrorColor: colors.error,
    decoration: InputDecoration(
      labelText: AppLocalizations.of(context).phoneNumber,
      labelStyle: TextStyle(color: colors.onSurfaceVariant),
      hintText: '+7 (700) 000-00-00',
      hintStyle: TextStyle(color: colors.onSurfaceVariant),
      errorStyle: TextStyle(color: colors.error),
      prefixIcon: Icon(Icons.phone_outlined, color: colors.primary),
    ),
    onSubmitted: (_) => _step == _LoginStep.login ? _login() : _requestCode(),
  );

  Widget _codeField(ColorScheme colors) => TextField(
    key: const Key('flash_call_code_field'),
    controller: _codeController,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(4),
    ],
    textAlign: TextAlign.center,
    style: TextStyle(
      color: colors.onSurface,
      fontSize: 28,
      letterSpacing: 14,
      fontWeight: FontWeight.w600,
    ),
    cursorColor: colors.primary,
    decoration: InputDecoration(
      labelText: AppLocalizations.of(context).lastFourDigits,
      counterText: '',
    ),
    maxLength: 4,
    onSubmitted: (_) => _verifyCode(),
  );

  Widget _passwordField(ColorScheme colors) => TextField(
    key: Key(
      _step == _LoginStep.login
          ? 'login_password_field'
          : 'register_password_field',
    ),
    controller: _passwordController,
    obscureText: true,
    style: TextStyle(color: colors.onSurface),
    cursorColor: colors.primary,
    decoration: InputDecoration(
      labelText: AppLocalizations.of(context).passwordLabel,
      prefixIcon: const Icon(Icons.lock_outline),
    ),
    onSubmitted: (_) => _step == _LoginStep.login ? _login() : _setPassword(),
  );

  Widget _confirmPasswordField(ColorScheme colors) => TextField(
    key: const Key('register_confirm_password_field'),
    controller: _confirmPasswordController,
    obscureText: true,
    style: TextStyle(color: colors.onSurface),
    cursorColor: colors.primary,
    decoration: InputDecoration(
      labelText: AppLocalizations.of(context).confirmPassword,
      prefixIcon: const Icon(Icons.lock_outline),
    ),
    onSubmitted: (_) => _setPassword(),
  );
}
