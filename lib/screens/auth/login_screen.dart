import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/active_order_service.dart';
import '../../services/tulpar_api_client.dart';
import '../../services/tulpar_auth_session.dart';
import '../../utils/formatters.dart';
import '../driver/driver_map_screen.dart';
import '../map/map_screen.dart';
import '../map/order_tracking_screen.dart';

enum _LoginStep { phone, code, profile }

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.authController,
    this.apiClient,
    this.activeOrderLoader,
  });

  final TulparAuthController? authController;
  final TulparApiClient? apiClient;
  final Future<ActiveOrder?> Function()? activeOrderLoader;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  late final TulparAuthController _auth;
  late final TulparApiClient _apiClient;
  _LoginStep _step = _LoginStep.phone;
  String? _challengeId;
  String? _phone;
  bool _isLoading = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _auth = widget.authController ?? TulparAuthController.instance;
    _apiClient = widget.apiClient ?? TulparApiClient(tulparAuth: _auth);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!isCompleteRuPhone(_phoneController.text)) {
      _showError('Введите корректный номер телефона.');
      return;
    }
    final phone = normalizeRuPhone(_phoneController.text);
    await _run(() async {
      final challenge = await _auth.requestFlashCall(phone: phone);
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
      _showError('Введите последние 4 цифры номера звонящего.');
      return;
    }
    await _run(() async {
      final result = await _auth.verifyFlashCall(
        challengeId: _challengeId!,
        phone: _phone!,
        code: code,
      );
      if (!mounted) return;
      if (result.profileRequired) {
        setState(() => _step = _LoginStep.profile);
        return;
      }
      await _continueToApp();
    });
  }

  Future<void> _completeProfile() async {
    final name = _nameController.text.trim();
    if (name.length < 2 || name.length > 120) {
      _showError('Введите имя длиной от 2 до 120 символов.');
      return;
    }
    await _run(() async {
      await _apiClient.updateCurrentUserProfile(name: name);
      await _continueToApp();
    });
  }

  Future<void> _continueToApp() async {
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
      _showError(switch (error.code) {
        'resend_cooldown' => 'Повторный звонок пока недоступен.',
        'invalid_phone' => 'Проверьте номер телефона.',
        'invalid_verification' => 'Неверный или просроченный код.',
        _ => 'Не удалось выполнить вход. Попробуйте ещё раз.',
      });
    } on TulparApiException catch (error) {
      if (mounted) _showError(error.message);
    } on TimeoutException {
      if (mounted) _showError('Сервер не ответил. Попробуйте ещё раз.');
    } catch (_) {
      if (mounted) _showError('Не удалось выполнить вход. Попробуйте ещё раз.');
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
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 210,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.local_taxi,
                      size: 110,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(switch (_step) {
                    _LoginStep.phone => 'Вход в Tulpar',
                    _LoginStep.code => 'Подтверждение номера',
                    _LoginStep.profile => 'Как к вам обращаться?',
                  }, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(
                    switch (_step) {
                      _LoginStep.phone =>
                        'На ваш номер поступит короткий звонок.\nВведите последние 4 цифры номера звонящего.',
                      _LoginStep.code =>
                        'Введите последние 4 цифры номера входящего звонка',
                      _LoginStep.profile =>
                        'Имя будет отображаться в вашем профиле.',
                    },
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  if (_step == _LoginStep.phone) _phoneField(colors),
                  if (_step == _LoginStep.code) _codeField(colors),
                  if (_step == _LoginStep.profile) _nameField(colors),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      key: const Key('flash_call_primary_button'),
                      onPressed: _isLoading
                          ? null
                          : switch (_step) {
                              _LoginStep.phone => _requestCode,
                              _LoginStep.code => _verifyCode,
                              _LoginStep.profile => _completeProfile,
                            },
                      child: _isLoading
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(switch (_step) {
                              _LoginStep.phone => 'Получить код звонком',
                              _LoginStep.code => 'Подтвердить',
                              _LoginStep.profile => 'Продолжить',
                            }),
                    ),
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
                            ? 'Позвонить ещё раз через $_resendSeconds сек.'
                            : 'Позвонить ещё раз',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
      labelText: 'Номер телефона',
      labelStyle: TextStyle(color: colors.onSurfaceVariant),
      hintText: '+7 (700) 000-00-00',
      hintStyle: TextStyle(color: colors.onSurfaceVariant),
      errorStyle: TextStyle(color: colors.error),
      prefixIcon: Icon(Icons.phone_outlined, color: colors.primary),
    ),
    onSubmitted: (_) => _requestCode(),
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
    decoration: const InputDecoration(
      labelText: 'Последние 4 цифры',
      counterText: '',
    ),
    maxLength: 4,
    onSubmitted: (_) => _verifyCode(),
  );

  Widget _nameField(ColorScheme colors) => TextField(
    key: const Key('flash_call_profile_name_field'),
    controller: _nameController,
    textCapitalization: TextCapitalization.words,
    style: TextStyle(color: colors.onSurface),
    cursorColor: colors.primary,
    decoration: const InputDecoration(
      labelText: 'Имя',
      prefixIcon: Icon(Icons.person_outline),
    ),
    onSubmitted: (_) => _completeProfile(),
  );
}
