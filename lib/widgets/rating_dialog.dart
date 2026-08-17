import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RatingDialog extends StatefulWidget {
  final String targetUserId;
  final String orderId;
  final bool isRatingDriver;

  const RatingDialog({
    super.key,
    required this.targetUserId,
    required this.orderId,
    required this.isRatingDriver,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 5;

  Future<void> _submitRating() async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(widget.targetUserId);
    
    // Обновляем общий рейтинг пользователя
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        int currentSum = data['ratingSum'] ?? 0;
        int currentCount = data['ratingCount'] ?? 0;
        
        transaction.update(userRef, {
          'ratingSum': currentSum + _rating,
          'ratingCount': currentCount + 1,
        });
      }
    });

    // Записываем оценку в заказ
    await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
      widget.isRatingDriver ? 'driverRating' : 'passengerRating': _rating,
    });

    if (mounted) {
      Navigator.pop(context); // Закрываем диалог
      Navigator.pop(context); // Возвращаемся на главный экран
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isRatingDriver ? 'Оцените водителя' : 'Оцените пассажира'),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          return IconButton(
            icon: Icon(
              index < _rating ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 36,
            ),
            onPressed: () => setState(() => _rating = index + 1),
          );
        }),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
          onPressed: _submitRating,
          child: const Text('Отправить'),
        )
      ],
    );
  }
}