import 'dart:async';

/// Creates a stream that starts a fresh source subscription for every listener.
///
/// This is useful for polling streams returned by `async*`: those stream objects
/// are single-subscription, while a widget may legitimately stop listening and
/// listen again later in its lifecycle.
Stream<T> restartableStream<T>(Stream<T> Function() createSource) {
  return Stream<T>.multi((controller) {
    StreamSubscription<T>? subscription;

    subscription = createSource().listen(
      controller.addSync,
      onError: controller.addErrorSync,
      onDone: controller.closeSync,
    );

    controller.onPause = subscription.pause;
    controller.onResume = subscription.resume;
    controller.onCancel = () {
      unawaited(subscription?.cancel());
    };
  });
}
