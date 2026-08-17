import 'package:flutter/material.dart';

import '../../services/driver_agreement_service.dart';

class DriverAgreementScreen extends StatefulWidget {
  const DriverAgreementScreen({
    super.key,
    required this.userId,
    this.agreementService,
  });

  final String userId;
  final DriverAgreementService? agreementService;

  @override
  State<DriverAgreementScreen> createState() => _DriverAgreementScreenState();
}

class _DriverAgreementScreenState extends State<DriverAgreementScreen> {
  bool _isConfirmed = false;
  bool _isSaving = false;

  Future<void> _acceptAgreement() async {
    if (!_isConfirmed || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await (widget.agreementService ?? DriverAgreementService())
          .acceptCurrentAgreement(widget.userId);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить согласие. Попробуйте ещё раз.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Правила работы водителя')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Соглашение версии ${DriverAgreementService.currentVersion}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    'Переходя в режим водителя, я подтверждаю, что:\n\n'
                    '• имею право управлять автомобилем и использую технически исправный автомобиль;\n\n'
                    '• соблюдаю правила дорожного движения и требования безопасности;\n\n'
                    '• поддерживаю автомобиль в чистоте и вежливо общаюсь с пассажирами;\n\n'
                    '• не выхожу на линию в состоянии, которое мешает безопасному управлению;\n\n'
                    '• указываю достоверные сведения об автомобиле и не передаю аккаунт другим лицам;\n\n'
                    '• использую данные пассажира только для выполнения заказа.',
                    style: TextStyle(fontSize: 16, height: 1.35),
                  ),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isConfirmed,
                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() => _isConfirmed = value ?? false);
                      },
                title: const Text(
                  'Я прочитал(а) правила и принимаю соглашение',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isConfirmed && !_isSaving ? _acceptAgreement : null,
                child: _isSaving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Принять и продолжить'),
              ),
              TextButton(
                onPressed: _isSaving
                    ? null
                    : () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
