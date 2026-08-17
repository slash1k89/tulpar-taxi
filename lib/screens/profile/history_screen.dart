import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widgets/app_drawer.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final mode = appModeFromRoute(context);

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('История поездок')),
        drawer: AppDrawer(mode: mode),
        body: const Center(child: Text('Вы не авторизованы')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('История поездок')),
      drawer: AppDrawer(mode: mode),
      body: StreamBuilder<QuerySnapshot>(
        // Исправлено: запрашиваем записи только текущего пользователя
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where(
              Filter.or(
                Filter('passengerId', isEqualTo: currentUser.uid),
                Filter('driverId', isEqualTo: currentUser.uid),
              ),
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          // Фильтруем завершенные и отмененные заказы локально
          final historyDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'];
            return status == 'completed' || status == 'cancelled';
          }).toList();

          if (historyDocs.isEmpty) {
            return const Center(
              child: Text('У вас пока нет завершенных поездок'),
            );
          }

          return ListView.builder(
            itemCount: historyDocs.length,
            itemBuilder: (context, index) {
              final order = historyDocs[index].data() as Map<String, dynamic>;
              final isCompleted = order['status'] == 'completed';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    isCompleted ? Icons.check_circle : Icons.cancel,
                    color: isCompleted ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    '${order['fromAddress'] ?? ''} → ${order['toAddress'] ?? ''}',
                  ),
                  subtitle: Text('Цена: ${order['price'] ?? 0} ₸'),
                  trailing: Text(
                    isCompleted ? 'Завершен' : 'Отменен',
                    style: TextStyle(
                      color: isCompleted ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
