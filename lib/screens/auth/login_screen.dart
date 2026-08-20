import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../map/map_screen.dart';
import '../map/order_tracking_screen.dart';
import '../driver/driver_map_screen.dart';
import '../../services/active_order_service.dart';
import '../../services/user_profile_recovery_service.dart';
import '../../services/tulpar_api_client.dart';
import 'register_screen.dart';
import 'user_profile_recovery_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');

    if (rawPhone.length < 11 || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите корректный номер телефона и пароль'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Авторизация по номеру телефона (привязанному к email под капотом)
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: '$rawPhone@tulpar.kz',
        password: _passwordController.text.trim(),
      );

      await TulparApiClient().syncCurrentUser(phone: '+$rawPhone');

      UserProfileRecoveryResult? recovery;
      try {
        recovery = await UserProfileRecoveryService().inspectAndRepair();
      } catch (_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const UserProfileRecoveryScreen(),
            ),
          );
        }
        return;
      }

      if (!recovery.allowsAppAccess) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  UserProfileRecoveryScreen(initialResult: recovery),
            ),
          );
        }
        return;
      }

      final activeOrder = await ActiveOrderService().findCurrentOrder();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) {
              if (activeOrder == null) return const MapScreen();
              if (activeOrder.isDriver) {
                return DriverMapScreen(
                  orderId: activeOrder.orderId,
                  orderData: activeOrder.data,
                );
              }
              return OrderTrackingScreen(
                orderId: activeOrder.orderId,
                initialOrderData: activeOrder.data,
              );
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка входа: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Увеличенный и отцентрованный логотип
                Image.asset(
                  'assets/logo.png',
                  height: 230,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.local_taxi,
                      size: 120,
                      color: Colors.amber,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Вход в систему',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  key: const Key('login_phone_field'),
                  controller: _phoneController,
                  style: TextStyle(color: colorScheme.onSurface),
                  cursorColor: colorScheme.primary,
                  cursorErrorColor: colorScheme.error,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [RuPhoneInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Номер телефона',
                    labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    floatingLabelStyle: TextStyle(color: colorScheme.primary),
                    hintText: '+7 (700) 000-00-00',
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    errorStyle: TextStyle(color: colorScheme.error),
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('login_password_field'),
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(color: colorScheme.onSurface),
                  cursorColor: colorScheme.primary,
                  cursorErrorColor: colorScheme.error,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    floatingLabelStyle: TextStyle(color: colorScheme.primary),
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    errorStyle: TextStyle(color: colorScheme.error),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(
                            color: colorScheme.onPrimary,
                          )
                        : Text(
                            'Войти',
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Нет аккаунта? ',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Зарегистрироваться',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Форматировщик ввода номера телефона +7 (XXX) XXX-XX-XX
// Исправленный форматировщик номера телефона
class RuPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. Если поле полностью очищено — разрешаем очистку
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
    var newDigits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // 2. Если нажат Backspace и удален спецсимвол (скобка, дефис, пробел),
    // кол-во цифр не изменилось — принудительно удаляем последнюю цифру
    if (newValue.text.length < oldValue.text.length && oldDigits == newDigits) {
      if (newDigits.isNotEmpty) {
        newDigits = newDigits.substring(0, newDigits.length - 1);
      }
    }

    // 3. Если цифр больше нет — полностью очищаем поле
    if (newDigits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Убираем префикс 7 или 8, так как '+7 ' добавляется автоматически
    if (newDigits.startsWith('7') || newDigits.startsWith('8')) {
      newDigits = newDigits.substring(1);
    }

    // Ограничиваем максимум 10 цифрами после +7
    if (newDigits.length > 10) {
      newDigits = newDigits.substring(0, 10);
    }

    final buffer = StringBuffer('+7 ');
    if (newDigits.isNotEmpty) {
      buffer.write('(');
      buffer.write(
        newDigits.substring(0, newDigits.length >= 3 ? 3 : newDigits.length),
      );
      if (newDigits.length >= 3) {
        buffer.write(') ');
        buffer.write(
          newDigits.substring(3, newDigits.length >= 6 ? 6 : newDigits.length),
        );
      }
      if (newDigits.length >= 6) {
        buffer.write('-');
        buffer.write(
          newDigits.substring(6, newDigits.length >= 8 ? 8 : newDigits.length),
        );
      }
      if (newDigits.length >= 8) {
        buffer.write('-');
        buffer.write(
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
