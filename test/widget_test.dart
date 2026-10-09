// Basic smoke test: the app boots to a splash/login state without an
// authenticated session (no stored token in the test environment) and
// doesn't crash on first frame.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rvmi_media/app/app.dart';

void main() {
  testWidgets('App boots to splash/login without crashing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RvmiMediaApp()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
