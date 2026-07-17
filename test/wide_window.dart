import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Sizes the test window so the editor's whole app-bar row fits without
/// scrolling and the panels dock. The Phase 47 unified bar is the same
/// at every width, but at flutter_test's 800×600 default its trailing
/// buttons sit off-screen (taps would need a scroll first) and the
/// panels become drawers. Tests that tap bar affordances (File popup,
/// fit / reset / theme / keyboard buttons) or expect docked panels call
/// this before pumping; narrow-window behavior is covered by
/// `app_bar_layout_test.dart`.
void useWideTestWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
