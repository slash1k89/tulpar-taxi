import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../services/active_order_service.dart';
import '../../services/user_profile_recovery_service.dart';
import '../driver/driver_map_screen.dart';
import '../map/map_screen.dart';
import '../map/order_tracking_screen.dart';

class UserProfileRecoveryScreen extends StatefulWidget {
  const UserProfileRecoveryScreen({
    super.key,
    this.initialResult,
    this.service,
  });

  final UserProfileRecoveryResult? initialResult;
  final UserProfileRecoveryService? service;

  @override
  State<UserProfileRecoveryScreen> createState() =>
      _UserProfileRecoveryScreenState();
}

class _UserProfileRecoveryScreenState extends State<UserProfileRecoveryScreen> {
  final _nameController = TextEditingController();
  late final UserProfileRecoveryService _service;
  UserProfileRecoveryResult? _result;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? UserProfileRecoveryService();
    _result = widget.initialResult;
    if (_result != null) {
      _isLoading = false;
    } else {
      _inspect();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _inspect({String? confirmedName}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final result = await _service.inspectAndRepair(
        userProvidedName: confirmedName,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
      if (result.allowsAppAccess) await _continueToApp();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Не удалось проверить профиль. Проверьте интернет и повторите.';
        _isLoading = false;
      });
    }
  }

  Future<void> _continueToApp() async {
    final activeOrder = await ActiveOrderService().findCurrentOrder();
    if (!mounted) return;
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

  Future<void> _submitName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 80) {
      setState(() => _error = 'Введите имя длиной не более 80 символов.');
      return;
    }
    await _inspect(confirmedName: name);
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Восстановление профиля')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(
                    Icons.manage_accounts_outlined,
                    size: 72,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    result?.requiresTrustedMigration == true
                        ? 'Профиль имеет старый формат'
                        : result?.needsName == true
                        ? 'Укажите имя'
                        : 'Не удалось завершить проверку',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (result?.requiresTrustedMigration == true) ...[
                    const Text(
                      'Защищённые поля нельзя безопасно восстановить с телефона. '
                      'Для этого профиля требуется точечная административная миграция.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _FieldList(
                      title: 'Требуют административного восстановления:',
                      fields: result!.adminMigrationFields,
                    ),
                    if (result.legacyFieldsPresent) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Старые isDriver, driverActiveUntil и данные автомобиля '
                        'обнаружены, но не используются для выдачи водительских прав.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                  if (result?.needsName == true) ...[
                    const Text(
                      'Имя отсутствует в профиле и Firebase Auth. Введите своё имя — '
                      'остальные защищённые поля останутся без изменений.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('recovery_name_field'),
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Имя',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    ElevatedButton(
                      key: const Key('recover_profile_button'),
                      onPressed: _submitName,
                      child: const Text('Сохранить и продолжить'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton(
                    key: const Key('retry_profile_recovery_button'),
                    onPressed: _inspect,
                    child: const Text('Проверить снова'),
                  ),
                  TextButton(
                    key: const Key('recovery_sign_out_button'),
                    onPressed: _signOut,
                    child: const Text('Выйти из аккаунта'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FieldList extends StatelessWidget {
  const _FieldList({required this.title, required this.fields});

  final String title;
  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...fields.map(
          (field) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• ${_fieldLabel(field)}'),
          ),
        ),
      ],
    );
  }

  String _fieldLabel(String field) {
    return switch (field) {
      'uid' => 'идентификатор аккаунта (uid)',
      'name' => 'имя',
      'phone' => 'подтверждённый телефон',
      'role' => 'базовая роль passenger',
      'rating' => 'начальный рейтинг 5.0',
      'createdAt' => 'дата создания из Firebase Auth',
      _ => field,
    };
  }
}
