import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Sizes the test window so the editor builds its wide layout — docked
/// panels and the full app-bar action cluster. The Phase 42 chrome gate
/// compares the window width against ~980 px, and flutter_test's
/// 800×600 default falls on the compact side (it is exactly the
/// too-narrow-for-the-cluster window the gate exists for). Tests that
/// reach for wide-chrome affordances (File popup, fit / reset / theme /
/// keyboard buttons, docked panels) call this before pumping; compact
/// and tablet behavior is covered by `compact_layout_test.dart`.
void useWideTestWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
