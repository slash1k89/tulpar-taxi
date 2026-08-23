import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/utils/restartable_stream.dart';

void main() {
  test(
    'creates a fresh single-subscription source after cancellation',
    () async {
      var sourceCount = 0;

      Stream<int> createSource() async* {
        sourceCount++;
        yield sourceCount;
      }

      final stream = restartableStream(createSource);

      expect(await stream.first, 1);
      expect(await stream.first, 2);
      expect(sourceCount, 2);
    },
  );
}
