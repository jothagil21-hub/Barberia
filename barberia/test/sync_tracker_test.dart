import 'package:flutter_test/flutter_test.dart';

import 'package:barberia/core/sync/sync_tracker.dart';

void main() {
  test('clientId usa prefijo local estable', () {
    expect(SyncTracker.clientId('barber', 3), 'local-barber-3');
    expect(SyncTracker.clientId('appointment', 12), 'local-appointment-12');
  });
}
