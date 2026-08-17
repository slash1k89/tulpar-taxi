import 'package:flutter/material.dart';
import '../models/city.dart';

Future<City?> showCitySelectionModal(
  BuildContext context, {
  required String currentCityId,
}) async {
  return showModalBottomSheet<City>(
    context: context,
    isScrollControlled: true, // Исправлено: безопасное масштабирование
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Выберите город',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Flexible(
              // Исправлено: защита от Bottom Overflow
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableCities.length,
                itemBuilder: (context, index) {
                  final city = availableCities[index];
                  final isSelected = city.id == currentCityId;

                  return ListTile(
                    title: Text(city.name),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.amber)
                        : null,
                    onTap: () {
                      Navigator.pop(context, city);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
