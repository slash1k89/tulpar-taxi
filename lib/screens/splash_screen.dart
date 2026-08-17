import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/login_screen.dart';
import 'map/map_screen.dart';
import 'map/order_tracking_screen.dart';
import 'driver/driver_map_screen.dart';
import '../services/active_order_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/splash.mp4');
      await _controller.initialize();

      await _controller.setVolume(0.0);
      await _controller.setPlaybackSpeed(1.6);

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        _controller.play();
      }

      _controller.addListener(() {
        if (_controller.value.isInitialized &&
            _controller.value.position >= _controller.value.duration) {
          _navigateToNext();
        }
      });
    } catch (e) {
      debugPrint("Ошибка видео: $e");
      _navigateToNext();
    }
  }

  void _navigateToNext() {
    _navigateToNextAsync();
  }

  Future<void> _navigateToNextAsync() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
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
            return OrderTrackingScreen(orderId: activeOrder.orderId);
          },
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    if (_isVideoInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: _isVideoInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(color: Colors.amber),
      ),
    );
  }
}
