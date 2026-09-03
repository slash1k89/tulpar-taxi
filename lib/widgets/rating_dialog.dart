import 'package:flutter/material.dart';

import '../services/rating_service.dart';

class RatingDialog extends StatefulWidget {
  final String targetUserId;
  final String orderId;
  final bool isRatingDriver;
  final RatingService? ratingService;
  final String? targetLabel;

  const RatingDialog({
    super.key,
    required this.targetUserId,
    required this.orderId,
    required this.isRatingDriver,
    this.ratingService,
    this.targetLabel,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 5;
  bool _isSubmitting = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await (widget.ratingService ?? FirebaseRatingService()).submitRating(
        orderId: widget.orderId,
        targetUserId: widget.targetUserId,
        score: _rating,
        comment: widget.isRatingDriver ? _commentController.text.trim() : null,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on RatingSubmissionException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError(
        '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c '
        '\u043e\u0442\u043f\u0440\u0430\u0432\u0438\u0442\u044c '
        '\u043e\u0446\u0435\u043d\u043a\u0443. '
        '\u041f\u043e\u043f\u0440\u043e\u0431\u0443\u0439\u0442\u0435 '
        '\u0435\u0449\u0451 \u0440\u0430\u0437.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      title: Text(
        'Оцените ${widget.targetLabel ?? (widget.isRatingDriver ? 'водителя' : 'пассажира')}',
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              children: List.generate(5, (index) {
                return SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    key: ValueKey('rating_star_${index + 1}'),
                    tooltip: '${index + 1} из 5',
                    padding: const EdgeInsets.all(6),
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() => _rating = index + 1),
                  ),
                );
              }),
            ),
            if (widget.isRatingDriver) ...[
              const SizedBox(height: 16),
              TextField(
                key: const Key('rating_review'),
                controller: _commentController,
                enabled: !_isSubmitting,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Напишите отзыв (необязательно)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: const Text('\u041e\u0442\u043c\u0435\u043d\u0430'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
          onPressed: _isSubmitting ? null : _submitRating,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  '\u041e\u0442\u043f\u0440\u0430\u0432\u0438\u0442\u044c',
                ),
        ),
      ],
    );
  }
}
