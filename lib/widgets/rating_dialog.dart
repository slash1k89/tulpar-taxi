import 'package:flutter/material.dart';

import '../services/rating_service.dart';
import '../l10n/generated/app_localizations.dart';

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
      final l10n = AppLocalizations.of(context);
      _showError(switch (error.failure) {
        RatingSubmissionFailure.invalidRequest => l10n.ratingInvalidRequest,
        RatingSubmissionFailure.forbidden => l10n.ratingForbidden,
        RatingSubmissionFailure.orderMissing => l10n.ratingOrderMissing,
        RatingSubmissionFailure.alreadySent => l10n.ratingAlreadySent,
        RatingSubmissionFailure.notCompleted => l10n.ratingNotCompleted,
        RatingSubmissionFailure.invalidScore => l10n.ratingInvalidScore,
        RatingSubmissionFailure.failed => l10n.ratingFailed,
        null => l10n.ratingFailed,
      });
    } catch (_) {
      _showError(AppLocalizations.of(context).ratingFailed);
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
        widget.targetLabel != null
            ? AppLocalizations.of(context).ratingTitleName(widget.targetLabel!)
            : widget.isRatingDriver
            ? AppLocalizations.of(context).ratingTitleDriver
            : AppLocalizations.of(context).ratingTitlePassenger,
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
                    tooltip: AppLocalizations.of(
                      context,
                    ).ratingStarTooltip(index + 1),
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
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).ratingReviewHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: Text(AppLocalizations.of(context).ratingCancel),
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
              : Text(AppLocalizations.of(context).ratingSubmit),
        ),
      ],
    );
  }
}
