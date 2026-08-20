import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/theme_service.dart';
import '../../services/user_profile_service.dart';
import '../../widgets/app_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.repository,
    this.themeController,
    this.userId,
  });

  final UserProfileRepository? repository;
  final ThemeController? themeController;
  final String? userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _carController = TextEditingController();

  late final UserProfileRepository _repository;
  late final ThemeController _themeController;
  double _averageRating = 5;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  String? get _userId =>
      widget.userId ?? FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseUserProfileRepository();
    _themeController = widget.themeController ?? appThemeController;
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _carController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _loadError = 'Пользователь не авторизован';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final profile = await _repository.load(userId);
      if (!mounted) return;
      setState(() {
        _nameController.text = profile?.name ?? '';
        _phoneController.text = profile?.phone ?? '';
        _carController.text = profile?.carModel ?? '';
        _averageRating = profile?.averageRating ?? 5;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Не удалось загрузить профиль';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    final userId = _userId;
    if (userId == null) return;

    setState(() => _isSaving = true);
    try {
      await _repository.update(
        userId: userId,
        name: _nameController.text.trim(),
        carModel: _carController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Профиль сохранён'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Профиль имеет старый формат. Если после заполнения имени ошибка повторится, проверьте uid, телефон, роль и дату создания в Firebase.'
                : 'Не удалось сохранить профиль: ${error.code}.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось сохранить профиль.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = appModeFromRoute(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль и настройки')),
      drawer: AppDrawer(mode: mode),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(child: Text(_loadError!))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          child: Icon(Icons.person, size: 50),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber),
                            Text(
                              ' ${_averageRating.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('profile_name_field'),
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Имя',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) return 'Введите имя';
                      if (name.length > 80) return 'Имя слишком длинное';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('profile_phone_field'),
                    controller: _phoneController,
                    readOnly: true,
                    enableInteractiveSelection: true,
                    decoration: const InputDecoration(
                      labelText: 'Номер телефона',
                      helperText: 'Номер телефона нельзя изменить',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('profile_car_field'),
                    controller: _carController,
                    decoration: const InputDecoration(
                      labelText: 'Марка и модель авто (для водителя)',
                      helperText: 'Пассажиру это поле заполнять не обязательно',
                      prefixIcon: Icon(Icons.directions_car_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<AppThemePreference>(
                    key: const Key('theme_preference_field'),
                    initialValue: _themeController.preference,
                    decoration: const InputDecoration(
                      labelText: 'Тема',
                      prefixIcon: Icon(Icons.palette_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: AppThemePreference.system,
                        child: Text('Как в системе'),
                      ),
                      DropdownMenuItem(
                        value: AppThemePreference.light,
                        child: Text('Светлая'),
                      ),
                      DropdownMenuItem(
                        value: AppThemePreference.dark,
                        child: Text('Тёмная'),
                      ),
                    ],
                    onChanged: (preference) {
                      if (preference != null) {
                        _themeController.setPreference(preference);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    key: const Key('save_profile_button'),
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: _isSaving
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Сохранить данные'),
                  ),
                ],
              ),
            ),
    );
  }
}
