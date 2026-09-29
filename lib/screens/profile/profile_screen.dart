import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../services/theme_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/account_deletion_service.dart';
import '../../app_routes.dart';
import '../../widgets/app_drawer.dart';
import '../../services/app_identity_service.dart';
import '../../services/voice_guidance_settings.dart';
import '../../services/locale_controller.dart';
import '../../l10n/generated/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.repository,
    this.themeController,
    this.userId,
    this.accountDeletionController,
    this.voiceGuidanceSettings,
  });

  final UserProfileRepository? repository;
  final ThemeController? themeController;
  final String? userId;
  final AccountDeletionController? accountDeletionController;
  final VoiceGuidanceSettings? voiceGuidanceSettings;

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
  late final VoiceGuidanceSettings _voiceGuidanceSettings;
  double _averageRating = 5;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _loadError;

  String? get _userId => widget.userId ?? AppIdentityService().currentUserId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseUserProfileRepository();
    _themeController = widget.themeController ?? appThemeController;
    _voiceGuidanceSettings =
        widget.voiceGuidanceSettings ?? appVoiceGuidanceSettings;
    _voiceGuidanceSettings.addListener(_handleVoiceSettingChanged);
    _voiceGuidanceSettings.load();
    _loadUserData();
  }

  void _handleVoiceSettingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _carController.dispose();
    _voiceGuidanceSettings.removeListener(_handleVoiceSettingChanged);
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _loadError = 'not_authenticated';
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
        _loadError = 'load_failed';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    final userId = _userId;
    if (userId == null) return;
    final isDriver = appModeFromRoute(context) == AppMode.driver;

    setState(() => _isSaving = true);
    try {
      await _repository.update(
        userId: userId,
        name: _nameController.text.trim(),
        carModel: isDriver ? _carController.text.trim() : '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).profileSaved),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? AppLocalizations.of(context).profileLegacyError
                : AppLocalizations.of(context).profileSaveCodeError(error.code),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).profileSaveFailed),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _confirmDeletion({required bool finalConfirmation}) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            key: Key(
              finalConfirmation
                  ? 'account_delete_second_dialog'
                  : 'account_delete_first_dialog',
            ),
            title: Text(
              finalConfirmation
                  ? AppLocalizations.of(dialogContext).profileDeleteFinalTitle
                  : AppLocalizations.of(dialogContext).profileDeleteTitle,
            ),
            content: Text(
              finalConfirmation
                  ? AppLocalizations.of(dialogContext).profileDeleteFinalWarning
                  : AppLocalizations.of(dialogContext).profileDeleteWarning,
            ),
            actions: [
              TextButton(
                key: Key(
                  finalConfirmation
                      ? 'account_delete_second_cancel'
                      : 'account_delete_first_cancel',
                ),
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(AppLocalizations.of(dialogContext).cancel),
              ),
              TextButton(
                key: Key(
                  finalConfirmation
                      ? 'account_delete_second_confirm'
                      : 'account_delete_first_confirm',
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: Text(
                  finalConfirmation
                      ? AppLocalizations.of(dialogContext).profileYesDelete
                      : AppLocalizations.of(dialogContext).continueLabel,
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _requestCurrentPassword() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PasswordConfirmationDialog(),
    );
  }

  Future<void> _deleteAccount() async {
    if (_isDeleting || !await _confirmDeletion(finalConfirmation: false)) {
      return;
    }
    if (!mounted || !await _confirmDeletion(finalConfirmation: true)) return;
    if (!mounted) return;
    final password = await _requestCurrentPassword();
    if (!mounted || password == null) return;

    setState(() => _isDeleting = true);
    try {
      final controller =
          widget.accountDeletionController ??
          DefaultAccountDeletionController();
      final outcome = await controller.deleteWithPassword(password);
      if (!mounted) return;
      final message = outcome == AccountDeletionOutcome.deleted
          ? AppLocalizations.of(context).profileDeleted
          : AppLocalizations.of(context).profileDeletionPending;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    } on AccountDeletionException catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final message = switch (error.code) {
        'wrong_password' => l10n.profileWrongPassword,
        'too_many_requests' => l10n.profileTooManyAttempts,
        'network_error' => l10n.profileNetworkError,
        'user_disabled' => l10n.profileUserDisabled,
        'user_not_found' => l10n.profileUserNotFound,
        'recent_login_required' => l10n.profileRecentLoginRequired,
        'active_order' => l10n.profileActiveOrder,
        'active_driver_order' => l10n.profileActiveDriverOrder,
        'active_ride' => l10n.profileActiveRide,
        'active_booking' => l10n.profileActiveBooking,
        'active_ride_request' => l10n.profileActiveRideRequest,
        'account_deletion_manual_recovery_required' =>
          l10n.profileDeletionManualReview,
        'account_deletion_result_unknown' => l10n.profileDeletionUnknown,
        _ => l10n.profileReauthFailed,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).profileDeleteFailed),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = appModeFromRoute(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).profileSettingsTitle),
      ),
      drawer: AppDrawer(mode: mode),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Text(
                _loadError == 'not_authenticated'
                    ? AppLocalizations.of(context).profileNotAuthenticated
                    : AppLocalizations.of(context).profileLoadFailed,
              ),
            )
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
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).profileName,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) {
                        return AppLocalizations.of(context).profileEnterName;
                      }
                      if (name.length > 80) {
                        return AppLocalizations.of(context).profileNameTooLong;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('profile_phone_field'),
                    controller: _phoneController,
                    readOnly: true,
                    enableInteractiveSelection: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).profilePhone,
                      helperText: AppLocalizations.of(
                        context,
                      ).profilePhoneReadonly,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  if (mode == AppMode.driver) ...[
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const Key('profile_car_field'),
                      controller: _carController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).profileCar,
                        prefixIcon: const Icon(Icons.directions_car_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  DropdownButtonFormField<AppThemePreference>(
                    key: const Key('theme_preference_field'),
                    initialValue: _themeController.preference,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).profileTheme,
                      prefixIcon: const Icon(Icons.palette_outlined),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: AppThemePreference.system,
                        child: Text(
                          AppLocalizations.of(context).profileThemeSystem,
                        ),
                      ),
                      DropdownMenuItem(
                        value: AppThemePreference.light,
                        child: Text(
                          AppLocalizations.of(context).profileThemeLight,
                        ),
                      ),
                      DropdownMenuItem(
                        value: AppThemePreference.dark,
                        child: Text(
                          AppLocalizations.of(context).profileThemeDark,
                        ),
                      ),
                    ],
                    onChanged: (preference) {
                      if (preference != null) {
                        _themeController.setPreference(preference);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'profile_language_${Localizations.localeOf(context).languageCode}',
                    ),
                    initialValue:
                        appLocaleController.effectiveLocale.languageCode,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).languageSetting,
                      prefixIcon: const Icon(Icons.language),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ru', child: Text('Русский')),
                      DropdownMenuItem(value: 'kk', child: Text('Қазақша')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (code) {
                      if (code != null) {
                        unawaited(appLocaleController.choose(code));
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    key: const Key('voice_guidance_setting'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(AppLocalizations.of(context).profileVoice),
                    subtitle: Text(
                      AppLocalizations.of(context).profileVoiceHint,
                    ),
                    secondary: const Icon(Icons.volume_up_outlined),
                    value: _voiceGuidanceSettings.enabled,
                    onChanged: _voiceGuidanceSettings.setEnabled,
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    key: const Key('about_support_link'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline),
                    title: Text(
                      AppLocalizations.of(context).aboutSupportTitle,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.aboutSupport),
                  ),
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
                        : Text(AppLocalizations.of(context).profileSave),
                  ),
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('delete_account_button'),
                    onPressed: _isDeleting ? null : _deleteAccount,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: _isDeleting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_forever_outlined),
                    label: Text(
                      AppLocalizations.of(context).profileDeleteTitle,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PasswordConfirmationDialog extends StatefulWidget {
  const _PasswordConfirmationDialog();

  @override
  State<_PasswordConfirmationDialog> createState() =>
      _PasswordConfirmationDialogState();
}

class _PasswordConfirmationDialogState
    extends State<_PasswordConfirmationDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('account_delete_password_dialog'),
      title: Text(AppLocalizations.of(context).profilePasswordTitle),
      content: TextField(
        key: const Key('account_delete_password_field'),
        controller: _controller,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).profileCurrentPassword,
          errorText: _errorText,
        ),
      ),
      actions: [
        TextButton(
          key: const Key('account_delete_password_cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          key: const Key('account_delete_password_confirm'),
          onPressed: () {
            if (_controller.text.isEmpty) {
              setState(
                () => _errorText = AppLocalizations.of(
                  context,
                ).profileEnterPassword,
              );
              return;
            }
            Navigator.pop(context, _controller.text);
          },
          child: Text(AppLocalizations.of(context).profileDeleteTitle),
        ),
      ],
    );
  }
}
