import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/splash_startup_service.dart';
import 'auth/login_screen.dart';
import 'driver/driver_map_screen.dart';
import 'map/map_screen.dart';
import 'map/order_tracking_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.startupLoader,
    this.timeoutFallback,
    this.onNavigate,
    this.initializeVideo = true,
    this.minimumDuration = const Duration(seconds: 2),
    this.maximumDuration = const Duration(milliseconds: 2750),
  });

  final Future<SplashDestination> Function()? startupLoader;
  final SplashDestination Function()? timeoutFallback;
  final ValueChanged<SplashDestination>? onNavigate;
  final bool initializeVideo;
  final Duration minimumDuration;
  final Duration maximumDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _isVideoInitialized = false;
  bool _hasNavigated = false;

  SplashStartupService? _startupService;
  late final Future<SplashDestination> _destinationFuture;

  @override
  void initState() {
    super.initState();
    if (widget.startupLoader != null) {
      _destinationFuture = widget.startupLoader!.call();
    } else {
      final startupService = SplashStartupService();
      _startupService = startupService;
      _destinationFuture = startupService.loadDestination();
    }
    unawaited(_completeStartup());
    if (widget.initializeVideo) unawaited(_initializeVideo());
  }

  Future<void> _initializeVideo() async {
    final controller = VideoPlayerController.asset('assets/splash.mp4');
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setVolume(0);
      await controller.setPlaybackSpeed(2);
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() => _isVideoInitialized = true);
    } catch (error) {
      debugPrint('Ошибка видео: $error');
    }
  }

  Future<void> _completeStartup() async {
    final destination = _destinationFuture
        .timeout(widget.maximumDuration, onTimeout: _fallbackDestination)
        .catchError((_) => _fallbackDestination());

    await Future<void>.delayed(widget.minimumDuration);
    _navigateOnce(await destination);
  }

  SplashDestination _fallbackDestination() {
    if (widget.timeoutFallback != null) {
      return widget.timeoutFallback!.call();
    }
    return (_startupService ??= SplashStartupService()).fallbackDestination();
  }

  void _navigateOnce(SplashDestination destination) {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    if (widget.onNavigate != null) {
      widget.onNavigate!(destination);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => _destinationScreen(destination)),
    );
  }

  Widget _destinationScreen(SplashDestination destination) {
    final activeOrder = destination.activeOrder;
    return switch (destination.target) {
      SplashTarget.login => const LoginScreen(),
      SplashTarget.map => const MapScreen(),
      SplashTarget.passengerOrder => OrderTrackingScreen(
        orderId: activeOrder!.orderId,
      ),
      SplashTarget.driverOrder => DriverMapScreen(
        orderId: activeOrder!.orderId,
        orderData: activeOrder.data,
      ),
    };
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: _isVideoInitialized && _controller != null
            ? AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              )
            : const CircularProgressIndicator(color: Colors.amber),
      ),
    );
  }
}
