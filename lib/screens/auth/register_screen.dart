import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../services/auth_service.dart';
import '../../l10n/generated/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;
  bool _isLoading = false;

  // Маска формата +7 (ххх) ххх-хх-хх
  final MaskTextInputFormatter _phoneFormatter = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 10 цифр без кода страны (например: 7000000000)
      String rawPhone = _phoneFormatter.getUnmaskedText();
      // Приводим к 11 цифрам с префиксом 7 (77000000000)
      String fullPhone = '7$rawPhone';
      String password = _passwordController.text.trim();

      final errorMessage = await AuthService().registerUser(
        name: _nameController.text,
        phone: '+$fullPhone',
        password: password,
      );

      if (errorMessage != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.registrationSuccess('+$fullPhone')),
            backgroundColor: Colors.green,
          ),
        );
        // Возвращаем пользователя на экран входа после успеха
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).registerUnexpectedError),
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(l10n.registerTitle),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.createAccount,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  TextFormField(
                    key: const Key('register_name_field'),
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(color: colorScheme.onSurface),
                    cursorColor: colorScheme.primary,
                    cursorErrorColor: colorScheme.error,
                    decoration: InputDecoration(
                      labelText: l10n.nameLabel,
                      labelStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      errorStyle: TextStyle(color: colorScheme.error),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      prefixIcon: Icon(
                        Icons.person,
                        color: colorScheme.primary,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.amber,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.enterName;
                      }
                      if (value.trim().length > 80) {
                        return l10n.nameTooLong;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // 1. Поле телефона с маской +7 (xxx) xxx-xx-xx
                  TextFormField(
                    key: const Key('register_phone_field'),
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [_phoneFormatter],
                    style: TextStyle(color: colorScheme.onSurface),
                    cursorColor: colorScheme.primary,
                    cursorErrorColor: colorScheme.error,
                    decoration: InputDecoration(
                      labelText: l10n.phoneNumber,
                      labelStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      hintText: '+7 (700) 000-00-00',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      errorStyle: TextStyle(color: colorScheme.error),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      prefixIcon: Icon(Icons.phone, color: colorScheme.primary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.amber,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      String unmasked = _phoneFormatter.getUnmaskedText();
                      if (unmasked.isEmpty) {
                        return l10n.enterPhone;
                      }
                      if (unmasked.length < 10) {
                        return l10n.enterFullPhone;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // 2. Поле ввода пароля
                  TextFormField(
                    key: const Key('register_password_field'),
                    controller: _passwordController,
                    obscureText: _isPasswordHidden,
                    style: TextStyle(color: colorScheme.onSurface),
                    cursorColor: colorScheme.primary,
                    cursorErrorColor: colorScheme.error,
                    decoration: InputDecoration(
                      labelText: l10n.passwordLabel,
                      labelStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      errorStyle: TextStyle(color: colorScheme.error),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: colorScheme.primary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordHidden
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordHidden = !_isPasswordHidden;
                          });
                        },
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.amber,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.enterPassword;
                      }
                      if (value.length < 6) {
                        return l10n.shortPassword;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // 3. Поле повтора пароля с проверкой совпадения
                  TextFormField(
                    key: const Key('register_confirm_password_field'),
                    controller: _confirmPasswordController,
                    obscureText: _isConfirmPasswordHidden,
                    style: TextStyle(color: colorScheme.onSurface),
                    cursorColor: colorScheme.primary,
                    cursorErrorColor: colorScheme.error,
                    decoration: InputDecoration(
                      labelText: l10n.confirmPassword,
                      labelStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      errorStyle: TextStyle(color: colorScheme.error),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      prefixIcon: Icon(Icons.lock, color: colorScheme.primary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordHidden
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordHidden =
                                !_isConfirmPasswordHidden;
                          });
                        },
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.amber,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.confirmPassword;
                      }
                      if (value != _passwordController.text) {
                        return l10n.passwordMismatch;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // 4. Кнопка «Зарегистрироваться»
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : Text(
                              l10n.registerButton,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
