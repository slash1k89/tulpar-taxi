import 'package:flutter/material.dart';
import 'map/map_screen.dart'; // Подключаем карту

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    // Вставляем ваш готовый экран карты!
    return const MapScreen();
  }
}
