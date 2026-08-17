import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'driver_screen.dart';

class DriverOnboardingScreen extends StatefulWidget {
  const DriverOnboardingScreen({super.key});

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  int _currentStep = 0;

  // Шаг 1: Согласие
  bool _isCleanCarAgreed = false;
  bool _isRulesAgreed = false;

  // Шаг 2: Оплата
  String _selectedPlan = '1_day'; // '1_day' или '1_week'

  // Шаг 3: Автомобиль
  final _carModelController = TextEditingController();
  final _carColorController = TextEditingController();
  final _carNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  @override
  void dispose() {
    _carModelController.dispose();
    _carColorController.dispose();
    _carNumberController.dispose();
    super.dispose();
  }

  Future<void> _completeRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final days = _selectedPlan == '1_day' ? 1 : 7;
      final activeUntil = DateTime.now().add(Duration(days: days));

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isDriver': true,
        'driverActiveUntil': Timestamp.fromDate(activeUntil),
        'carModel': _carModelController.text.trim(),
        'carColor': _carColorController.text.trim(),
        'carNumber': _carNumberController.text.trim().toUpperCase(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка активации: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Активация режима водителя'),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.amber,
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0) {
            if (!_isCleanCarAgreed || !_isRulesAgreed) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Подтвердите все условия правила!')),
              );
              return;
            }
            setState(() => _currentStep = 1);
          } else if (_currentStep == 1) {
            setState(() => _currentStep = 2);
          } else if (_currentStep == 2) {
            _completeRegistration();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          } else {
            Navigator.pop(context);
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Text(
                            _currentStep == 2 ? 'Оплатить и начать' : 'Далее',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Назад', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          // Шаг 1: Требования
          Step(
            title: const Text('Требования и согласие', style: TextStyle(color: Colors.white)),
            isActive: _currentStep >= 0,
            content: Column(
              children: [
                CheckboxListTile(
                  title: const Text('Чистый салон и кузов авто', style: TextStyle(color: Colors.white70)),
                  value: _isCleanCarAgreed,
                  activeColor: Colors.amber,
                  onChanged: (val) => setState(() => _isCleanCarAgreed = val ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Соблюдение ПДД и вежливость с пассажирами', style: TextStyle(color: Colors.white70)),
                  value: _isRulesAgreed,
                  activeColor: Colors.amber,
                  onChanged: (val) => setState(() => _isRulesAgreed = val ?? false),
                ),
              ],
            ),
          ),
          // Шаг 2: Оплата
          Step(
            title: const Text('Выбор смены (Доступ)', style: TextStyle(color: Colors.white)),
            isActive: _currentStep >= 1,
            content: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('1 День — 500 ₸', style: TextStyle(color: Colors.white)),
                  value: '1_day',
                  groupValue: _selectedPlan,
                  activeColor: Colors.amber,
                  onChanged: (val) => setState(() => _selectedPlan = val!),
                ),
                RadioListTile<String>(
                  title: const Text('1 Неделя — 2 500 ₸', style: TextStyle(color: Colors.white)),
                  value: '1_week',
                  groupValue: _selectedPlan,
                  activeColor: Colors.amber,
                  onChanged: (val) => setState(() => _selectedPlan = val!),
                ),
              ],
            ),
          ),
          // Шаг 3: Данные авто
          Step(
            title: const Text('Данные автомобиля', style: TextStyle(color: Colors.white)),
            isActive: _currentStep >= 2,
            content: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _carModelController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Марка и модель (напр. Toyota Camry)',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Заполните марку' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _carColorController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Цвет кузова',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Заполните цвет' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _carNumberController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Гос. номер (напр. 777 ABC 01)',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Заполните номер' : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}