import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/new_order_arrival_tracker.dart';

void main() {
  test('new order voice cue uses the dedicated asset and spoken fallback', () {
    expect(newOrderVoiceCue.assetPaths, ['audio/navigation/order_new.mp3']);
    expect(newOrderVoiceCue.fallbackText, 'Поступил новый заказ.');
  });

  test('initial list is silent', () {
    final tracker = NewOrderArrivalTracker();
    expect(tracker.process(['A', 'B']), isFalse);
  });

  test('one new order requests one sound', () {
    final tracker = NewOrderArrivalTracker();
    tracker.process(['A', 'B']);
    expect(tracker.process(['A', 'B', 'C']), isTrue);
  });

  test('repeated identical list is silent', () {
    final tracker = NewOrderArrivalTracker();
    tracker.process(['A', 'B']);
    tracker.process(['A', 'B', 'C']);
    expect(tracker.process(['A', 'B', 'C']), isFalse);
  });

  test('field changes with the same IDs are silent', () {
    final tracker = NewOrderArrivalTracker();
    tracker.process(['A', 'B']);
    expect(tracker.process(['A', 'B']), isFalse);
  });

  test('multiple new orders request only one sound for the batch', () {
    final tracker = NewOrderArrivalTracker();
    tracker.process(['A', 'B']);
    expect(tracker.process(['A', 'B', 'C', 'D', 'E']), isTrue);
    expect(tracker.process(['A', 'B', 'C', 'D', 'E']), isFalse);
  });

  test('removed and returning order stays known during the session', () {
    final tracker = NewOrderArrivalTracker();
    tracker.process(['A', 'B']);
    expect(tracker.process(['A']), isFalse);
    expect(tracker.process(['A', 'B']), isFalse);
  });

  test('inactive and disposed tracker never requests playback', () {
    final tracker = NewOrderArrivalTracker();
    tracker.process(['A']);
    tracker.setActive(false);
    expect(tracker.process(['A', 'B']), isFalse);

    tracker.setActive(true);
    expect(tracker.process(['A', 'B']), isFalse);
    tracker.dispose();
    expect(tracker.process(['A', 'B', 'C']), isFalse);
  });
}
