import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:regula/application/providers/experimental_prover_provider.dart';
import 'package:regula/application/providers/preferences_provider.dart';
import 'package:regula/application/providers/proof_highlight_provider.dart';
import 'package:regula/application/providers/prover_provider.dart';
import 'package:regula/application/providers/question_draft_provider.dart';
import 'package:regula/domain/prover/question_template.dart';
import 'package:regula/main.dart';
import 'package:regula/presentation/panels/proof_panel.dart';
import 'package:regula/presentation/panels/question_builder_bar.dart';

import '../editor_container.dart';

/// Intent 003: the prover is an experimental feature, off by default,
/// switched on and off from the view menu's Experimental section.
void main() {
  late ProviderContainer container;

  const wide = Size(1280, 800);
  const phone = Size(400, 800);

  Future<void> pumpEditor(
    WidgetTester tester, {
    required Size screen,
    bool prover = false,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = await editorContainer(prover: prover);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditorScreen()),
      ),
    );
  }

  /// Settles, unless a proof step is highlighted: the canvas pulses the
  /// emphasis for as long as one is, so nothing would settle.
  Future<void> settle(WidgetTester tester) async {
    if (container.read(proofHighlightProvider).isEmpty) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  /// The app bar scrolls on a phone, so its trailing buttons are built
  /// but may sit off-screen: scrolled to before a tap.
  Future<void> tapAppBar(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      80,
      scrollable: find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(target);
    await settle(tester);
  }

  final proofButton = find.descendant(
    of: find.byType(AppBar),
    matching: find.byIcon(Icons.fact_check_outlined),
  );

  Future<void> toggleProver(WidgetTester tester) async {
    await tapAppBar(tester, find.byTooltip('View'));
    // The whole item, not its text (grid_menu_test's ListTile quirk).
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<VoidCallback>, 'Prover'),
    );
    await settle(tester);
  }

  void expectNoProverSurface() {
    expect(proofButton, findsNothing);
    expect(find.byTooltip('Proof'), findsNothing);
    expect(find.byType(ProofPanel), findsNothing);
    expect(find.byType(QuestionBuilderBar), findsNothing);
    expect(container.read(proofHighlightProvider), isEmpty);
  }

  for (final (name, screen) in [('wide', wide), ('phone', phone)]) {
    group('$name:', () {
      testWidgets('a fresh install shows no trace of the prover', (
        tester,
      ) async {
        await pumpEditor(tester, screen: screen);
        expect(container.read(experimentalProverProvider), isFalse);
        expectNoProverSurface();
      });

      testWidgets('View → Experimental → Prover shows the Proof button, '
          'and only the button', (tester) async {
        await pumpEditor(tester, screen: screen);

        await tapAppBar(tester, find.byTooltip('View'));
        expect(find.text('Experimental'), findsOneWidget);
        final item = tester.widget<CheckedPopupMenuItem<VoidCallback>>(
          find.widgetWithText(CheckedPopupMenuItem<VoidCallback>, 'Prover'),
        );
        expect(item.checked, isFalse);
        await tester.tap(
          find.widgetWithText(CheckedPopupMenuItem<VoidCallback>, 'Prover'),
        );
        await tester.pumpAndSettle();

        expect(container.read(experimentalProverProvider), isTrue);
        expect(
          container
              .read(sharedPreferencesProvider)
              .getBool(ExperimentalProverNotifier.prefsKey),
          isTrue,
        );
        expect(proofButton, findsOneWidget);
        expect(find.byType(ProofPanel), findsNothing);
        expect(find.byType(QuestionBuilderBar), findsNothing);
      });
    });
  }

  testWidgets('off with the panel open, a question being built and a step '
      'highlighted takes all of it away; on again leaves the panel '
      'closed', (tester) async {
    await pumpEditor(tester, screen: wide, prover: true);

    await tapAppBar(tester, proofButton);
    container.read(questionDraftProvider.notifier).open(QuestionTemplate.perp);
    container.read(proofHighlightProvider.notifier).show(['a']);
    await tester.pump();
    expect(find.byType(ProofPanel), findsOneWidget);
    expect(find.byType(QuestionBuilderBar), findsOneWidget);

    await toggleProver(tester);

    expect(container.read(experimentalProverProvider), isFalse);
    expectNoProverSurface();
    expect(container.read(questionDraftProvider), isNull);
    expect(container.read(proverProvider), const ProverIdle());

    await toggleProver(tester);

    expect(proofButton, findsOneWidget);
    expect(
      find.byType(ProofPanel),
      findsNothing,
      reason: 'turning the prover on is not asking for its panel',
    );
  });
}
