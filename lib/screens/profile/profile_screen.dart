import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _carController = TextEditingController();
  double _avgRating = 5.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _carController.text = data['carModel'] ?? '';
        
        int sum = data['ratingSum'] ?? 0;
        int count = data['ratingCount'] ?? 0;
        if (count > 0) _avgRating = sum / count;
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'carModel': _carController.text,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль сохранен!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль'), backgroundColor: Colors.amber),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Center(
                    child: Column(
                      children: [
                        const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 50)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber),
                            Text(' ${_avgRating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Телефон', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _carController, decoration: const InputDecoration(labelText: 'Марка и номер авто (для водителя)', border: OutlineInputBorder())),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, minimumSize: const Size.fromHeight(50)),
                    onPressed: _saveProfile,
                    child: const Text('Сохранить данные', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}