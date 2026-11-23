import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:regula/application/providers/experimental_prover_provider.dart';
import 'package:regula/application/providers/proof_highlight_provider.dart';
import 'package:regula/application/providers/prover_provider.dart';
import 'package:regula/application/providers/question_draft_provider.dart';
import 'package:regula/domain/prover/question_template.dart';
import 'package:regula/main.dart';
import 'package:regula/presentation/panels/proof_panel.dart';
import 'package:regula/presentation/panels/question_builder_bar.dart';

import '../editor_container.dart';

/// Intents 003, 006 and 007: the prover is an experimental feature, off
/// on every fresh load, switched from "Prover" under the Experimental
/// header of the geometry menu — and on *is* its panel being open, so
/// there is no Proof button in the app bar at all.
void main() {
  late ProviderContainer container;

  const wide = Size(1280, 800);
  const phone = Size(400, 800);
  const geometryMenu = 'Geometry: Euclidean, hyperbolic or elliptic';

  Future<void> pumpEditor(WidgetTester tester, {required Size screen}) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = await editorContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditorScreen()),
      ),
    );
  }

  bool proverOn() => container.read(experimentalProverProvider);

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

  /// Through the menu, as a user does. The app bar scrolls on a phone,
  /// so the globe is scrolled to first.
  Future<void> toggleProver(WidgetTester tester) async {
    final globe = find.byTooltip(geometryMenu);
    await tester.scrollUntilVisible(
      globe,
      80,
      scrollable: find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(globe);
    await settle(tester);
    // The whole item, not its text (grid_menu_test's ListTile quirk).
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<VoidCallback>, 'Prover'),
    );
    await settle(tester);
  }

  void expectNoProverSurface() {
    expect(find.byIcon(Icons.fact_check_outlined), findsNothing);
    expect(find.byTooltip('Proof'), findsNothing);
    expect(find.byType(ProofPanel), findsNothing);
    expect(find.byType(QuestionBuilderBar), findsNothing);
    expect(container.read(proofHighlightProvider), isEmpty);
  }

  for (final (name, screen) in [('wide', wide), ('phone', phone)]) {
    group('$name:', () {
      testWidgets('a fresh load shows no trace of the prover', (tester) async {
        await pumpEditor(tester, screen: screen);
        expect(proverOn(), isFalse);
        expectNoProverSurface();
      });

      testWidgets('Prover in the geometry menu opens the panel, and no '
          'button joins the app bar', (tester) async {
        await pumpEditor(tester, screen: screen);

        await toggleProver(tester);

        expect(proverOn(), isTrue);
        expect(find.byType(ProofPanel), findsOneWidget);
        expect(find.byIcon(Icons.fact_check_outlined), findsNothing);
        expect(find.byTooltip('Proof'), findsNothing);
      });
    });
  }

  testWidgets('wide: off with the panel open, a question being built and a '
      'step highlighted takes all of it away; on again opens the panel', (
    tester,
  ) async {
    await pumpEditor(tester, screen: wide);
    await toggleProver(tester);
    container.read(questionDraftProvider.notifier).open(QuestionTemplate.perp);
    container.read(proofHighlightProvider.notifier).show(['a']);
    await tester.pump();
    expect(find.byType(ProofPanel), findsOneWidget);
    expect(find.byType(QuestionBuilderBar), findsOneWidget);

    await toggleProver(tester);

    expect(proverOn(), isFalse);
    expectNoProverSurface();
    expect(container.read(questionDraftProvider), isNull);
    expect(container.read(proverProvider), const ProverIdle());

    await toggleProver(tester);

    expect(proverOn(), isTrue);
    expect(find.byType(ProofPanel), findsOneWidget);
  });

  group('phone:', () {
    testWidgets('dismissing the sheet turns the prover off', (tester) async {
      await pumpEditor(tester, screen: phone);
      await toggleProver(tester);
      expect(find.byType(ProofPanel), findsOneWidget);

      // The scrim, above the sheet.
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();

      expect(find.byType(ProofPanel), findsNothing);
      expect(proverOn(), isFalse);
    });

    testWidgets('the sheet steps aside for a question and comes back when '
        'the builder is closed', (tester) async {
      await pumpEditor(tester, screen: phone);
      await toggleProver(tester);

      // What the panel's template chips do on a phone: open the draft,
      // then pop the sheet so the figure can be tapped.
      container
          .read(questionDraftProvider.notifier)
          .open(QuestionTemplate.perp);
      Navigator.of(tester.element(find.byType(ProofPanel))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ProofPanel), findsNothing);
      expect(find.byType(QuestionBuilderBar), findsOneWidget);
      expect(proverOn(), isTrue, reason: 'the sheet stepped aside, not off');

      await tester.tap(find.byTooltip('Close the question builder'));
      await tester.pumpAndSettle();

      expect(find.byType(QuestionBuilderBar), findsNothing);
      expect(find.byType(ProofPanel), findsOneWidget, reason: 'reopened');
      expect(proverOn(), isTrue);
    });
  });
}
