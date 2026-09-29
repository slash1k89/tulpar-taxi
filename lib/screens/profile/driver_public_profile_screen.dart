import 'package:flutter/material.dart';

import '../../services/tulpar_api_client.dart';
import '../../l10n/generated/app_localizations.dart';

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

  Future<String?> _reason() {
    final l10n = AppLocalizations.of(context);
    final values = [
      ('abuse', l10n.reportReasonAbuse),
      ('harassment', l10n.reportReasonHarassment),
      ('spam', l10n.reportReasonSpam),
      ('unsafe_behavior', l10n.reportReasonUnsafe),
      ('inappropriate_content', l10n.reportReasonInappropriate),
      ('other', l10n.reportReasonOther),
    ];
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(AppLocalizations.of(dialogContext).reportUser),
        children: values
            .map(
              (value) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, value.$1),
                child: Text(value.$2),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _report({String? driverId, String? reviewId}) async {
    final reason = await _reason();
    if (reason == null || !mounted) return;
    await (_api ??= TulparApiClient()).createContentReport(
      reportedUserId: reviewId == null ? driverId : null,
      contextType: reviewId == null ? 'user' : 'review',
      reasonCode: reason,
      orderId: reviewId == null ? widget.orderId : null,
      reviewId: reviewId,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).reportSent)),
      );
    }
  }

  Future<void> _block(String driverId) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(dialogContext).blockUser),
        content: Text(AppLocalizations.of(dialogContext).blockUserConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(dialogContext).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(dialogContext).blockUser),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await (_api ??= TulparApiClient()).blockUser(driverId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).userBlocked)),
      );
    }
  }

  @override
  void dispose() {
    _api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).driverProfile)),
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
                  Text(
                    AppLocalizations.of(context).publicDriverLoadFailed,
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => setState(() => _profile = _load()),
                    child: Text(AppLocalizations.of(context).retry),
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
        final driverId = data['driverId']?.toString();
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
              _text(data['name'], AppLocalizations.of(context).driver),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              rating is num && count > 0
                  ? '★ ${rating.toStringAsFixed(1)}'
                  : AppLocalizations.of(context).publicDriverNoRatings,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            if (count > 0)
              Text(
                AppLocalizations.of(
                  context,
                ).publicDriverRatingCount(count.toInt()),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(data['carModel'], AppLocalizations.of(context).car),
                      style: theme.textTheme.titleLarge,
                    ),
                    if (carDetails.isNotEmpty)
                      Text(carDetails, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (driverId?.isNotEmpty ?? false)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _report(driverId: driverId),
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(AppLocalizations.of(context).reportUser),
                  ),
                  TextButton.icon(
                    onPressed: () => _block(driverId!),
                    icon: const Icon(Icons.block),
                    label: Text(AppLocalizations.of(context).blockUser),
                  ),
                ],
              ),
            Text(
              AppLocalizations.of(context).publicDriverReviews,
              style: theme.textTheme.titleLarge,
            ),
            if (reviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(AppLocalizations.of(context).publicDriverNoReviews),
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
                      if (review['id']?.toString().isNotEmpty ?? false)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                _report(reviewId: review['id'].toString()),
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: Text(
                              AppLocalizations.of(context).reportUser,
                            ),
                          ),
                        ),
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
