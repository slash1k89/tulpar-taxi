import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../services/driver_profile_service.dart';
import '../../widgets/app_drawer.dart';
import 'driver_agreement_screen.dart';
import 'driver_screen.dart';
import '../../services/app_identity_service.dart';
import '../../l10n/generated/app_localizations.dart';

class DriverOnboardingScreen extends StatefulWidget {
  const DriverOnboardingScreen({
    super.key,
    this.repository,
    this.userId,
    this.driverDestinationBuilder,
  });

  final DriverProfileRepository? repository;
  final String? userId;
  final WidgetBuilder? driverDestinationBuilder;

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _carModelController = TextEditingController();
  final _carColorController = TextEditingController();
  final _carNumberController = TextEditingController();

  late final DriverProfileRepository _repository;
  late final String _userId;
  DriverProfile? _profile;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseDriverProfileRepository();
    _userId = widget.userId ?? AppIdentityService().currentUserId ?? '';
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      if (_userId.isEmpty) {
        _loadError = 'login_required';
        return;
      }
      final profile = await _repository.load(_userId);
      if (!mounted) return;
      _profile = profile;
      if (profile != null) {
        _carModelController.text = profile.carModel;
        _carColorController.text = profile.carColor;
        _carNumberController.text = profile.carNumber;
      }
    } on TimeoutException {
      _loadError = 'timeout';
    } on FirebaseException catch (error) {
      _loadError = 'firebase:${error.code}';
    } on DriverProfileException {
      _loadError = 'load_failed';
    } catch (_) {
      _loadError = 'load_failed';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptAgreement() async {
    await _repository.acceptCurrentAgreement(_userId);
  }

  Future<void> _submitVehicle() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final profile = await _repository.submitVehicle(
        userId: _userId,
        carModel: _carModelController.text,
        carColor: _carColorController.text,
        carNumber: _carNumberController.text,
      );
      if (!mounted) return;
      setState(() => _profile = profile);
      if (profile.status == DriverProfileStatus.approved) {
        _showMessage(AppLocalizations.of(context).onboardingActivated);
      }
    } on TimeoutException {
      _showMessage(AppLocalizations.of(context).onboardingRetryTimeout);
    } on FirebaseException catch (error) {
      _showMessage(_messageForFirebaseError(error));
    } on DriverProfileException {
      _showMessage(AppLocalizations.of(context).onboardingSubmitFailed);
    } catch (_) {
      _showMessage(AppLocalizations.of(context).onboardingSubmitFailed);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageForFirebaseError(FirebaseException error) {
    final l10n = AppLocalizations.of(context);
    return switch (error.code) {
      'permission-denied' => l10n.onboardingPermissionDenied,
      'unavailable' => l10n.onboardingUnavailable,
      _ => l10n.onboardingFirebaseError(error.code),
    };
  }

  @override
  void dispose() {
    _carModelController.dispose();
    _carColorController.dispose();
    _carNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }
    if (_loadError != null) return _buildError();

    return switch (resolveDriverOnboardingStep(_profile)) {
      DriverOnboardingStep.agreement => DriverAgreementScreen(
        userId: _userId,
        onAccept: _acceptAgreement,
        onAccepted: _loadProfile,
      ),
      DriverOnboardingStep.vehicle => _buildVehicleForm(),
      DriverOnboardingStep.pending => _buildStatusScreen(
        icon: Icons.hourglass_top,
        title: AppLocalizations.of(context).onboardingPendingTitle,
        description: AppLocalizations.of(context).onboardingPendingBody,
        actionLabel: AppLocalizations.of(context).onboardingCheckStatus,
        onAction: _loadProfile,
      ),
      DriverOnboardingStep.approved =>
        widget.driverDestinationBuilder?.call(context) ?? const DriverScreen(),
      DriverOnboardingStep.suspended => _buildStatusScreen(
        icon: Icons.block,
        title: AppLocalizations.of(context).onboardingSuspendedTitle,
        description: AppLocalizations.of(context).onboardingSuspendedBody,
        actionLabel: AppLocalizations.of(context).onboardingCheckAgain,
        onAction: _loadProfile,
      ),
    };
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).onboardingDriverMode),
      ),
      drawer: const AppDrawer(mode: AppMode.driver),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.orange, size: 54),
              const SizedBox(height: 16),
              Text(
                switch (_loadError!) {
                  'login_required' => AppLocalizations.of(
                    context,
                  ).onboardingLoginRequired,
                  'timeout' => AppLocalizations.of(
                    context,
                  ).onboardingServerTimeout,
                  'firebase:permission-denied' => AppLocalizations.of(
                    context,
                  ).onboardingPermissionDenied,
                  'firebase:unavailable' => AppLocalizations.of(
                    context,
                  ).onboardingUnavailable,
                  _ => AppLocalizations.of(context).onboardingLoadFailed,
                },
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadProfile,
                child: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleForm() {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).onboardingVehicleTitle),
      ),
      drawer: const AppDrawer(mode: AppMode.driver),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).onboardingFillVehicle,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).onboardingVehicleHint,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              _vehicleField(
                key: const Key('driver_car_model_field'),
                controller: _carModelController,
                label: AppLocalizations.of(context).onboardingCarModel,
                icon: Icons.directions_car,
                emptyMessage: AppLocalizations.of(
                  context,
                ).onboardingCarModelRequired,
                maximumLength: 80,
              ),
              const SizedBox(height: 16),
              _vehicleField(
                key: const Key('driver_car_color_field'),
                controller: _carColorController,
                label: AppLocalizations.of(context).onboardingCarColor,
                icon: Icons.color_lens,
                emptyMessage: AppLocalizations.of(
                  context,
                ).onboardingCarColorRequired,
                maximumLength: 40,
              ),
              const SizedBox(height: 16),
              _vehicleField(
                key: const Key('driver_car_number_field'),
                controller: _carNumberController,
                label: AppLocalizations.of(context).onboardingCarNumber,
                icon: Icons.pin,
                emptyMessage: AppLocalizations.of(
                  context,
                ).onboardingCarNumberRequired,
                maximumLength: 20,
                uppercase: true,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const Key('submit_driver_application_button'),
                  onPressed: _isSubmitting ? null : _submitVehicle,
                  child: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(AppLocalizations.of(context).onboardingSubmit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vehicleField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String emptyMessage,
    required int maximumLength,
    bool uppercase = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextFormField(
      key: key,
      controller: controller,
      style: TextStyle(color: colorScheme.onSurface),
      cursorColor: colorScheme.primary,
      cursorErrorColor: colorScheme.error,
      textCapitalization: uppercase
          ? TextCapitalization.characters
          : TextCapitalization.sentences,
      maxLength: maximumLength,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        errorStyle: TextStyle(color: colorScheme.error),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        prefixIcon: Icon(icon, color: colorScheme.primary),
      ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? emptyMessage : null,
    );
  }

  Widget _buildStatusScreen({
    required IconData icon,
    required String title,
    required String description,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).onboardingDriverMode),
      ),
      drawer: const AppDrawer(mode: AppMode.driver),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.amber, size: 64),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 24),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
