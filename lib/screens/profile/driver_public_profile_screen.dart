import 'package:flutter/material.dart';

import '../../services/tulpar_api_client.dart';

class DriverPublicProfileScreen extends StatefulWidget {
  const DriverPublicProfileScreen({
    super.key,
    required this.orderId,
    this.profileLoader,
  });

  final String orderId;
  final Future<Map<String, dynamic>> Function()? profileLoader;

  @override
  State<DriverPublicProfileScreen> createState() =>
      _DriverPublicProfileScreenState();
}

class _DriverPublicProfileScreenState extends State<DriverPublicProfileScreen> {
  TulparApiClient? _api;
  late Future<Map<String, dynamic>> _profile;

  @override
  void initState() {
    super.initState();
    _profile = _load();
  }

  Future<Map<String, dynamic>> _load() =>
      widget.profileLoader?.call() ??
      (_api ??= TulparApiClient()).getAssignedDriverProfile(widget.orderId);

  @override
  void dispose() {
    _api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Профиль водителя')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Не удалось загрузить профиль водителя',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => setState(() => _profile = _load()),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final rating = data['averageRating'];
        final count = data['ratingsCount'] as num? ?? 0;
        final reviews = (data['reviews'] as List? ?? const [])
            .whereType<Map>()
            .where(
              (r) =>
                  r['comment'] is String &&
                  (r['comment'] as String).trim().isNotEmpty,
            )
            .toList();
        final theme = Theme.of(context);
        final carDetails = [
          data['carColor'],
          data['carNumber'],
        ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.local_taxi, size: 56, color: Colors.amber),
            const SizedBox(height: 12),
            Text(
              _text(data['name'], 'Водитель'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              rating is num && count > 0
                  ? '★ ${rating.toStringAsFixed(1)}'
                  : 'Нет оценок',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            if (count > 0) Text('Оценок: $count', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(data['carModel'], 'Автомобиль'),
                      style: theme.textTheme.titleLarge,
                    ),
                    if (carDetails.isNotEmpty)
                      Text(carDetails, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Отзывы', style: theme.textTheme.titleLarge),
            if (reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Отзывов пока нет'),
              ),
            for (final review in reviews)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < ((review['score'] as num?) ?? 0)
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text((review['comment'] as String).trim()),
                      if (_date(review['createdAt'])
                          case final String date) ...[
                        const SizedBox(height: 8),
                        Text(
                          date,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  String _text(Object? value, String fallback) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;

  String? _date(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return null;
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
