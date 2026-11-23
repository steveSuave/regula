import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'proof_highlight_provider.dart';
import 'prover_provider.dart';
import 'question_draft_provider.dart';

part 'experimental_prover_provider.g.dart';

/// Whether the prover is on: "Prover" under the Experimental header of
/// the geometry menu, off on every fresh load (DECISIONS §"The prover is an
/// experimental toggle in the geometry menu").
///
/// On *is* the prover's panel being open — docked where there is room,
/// a sheet where there is not — so there is no separate Proof button to
/// lose. Session state, like the object tree's visibility, and not
/// stored: a stored "on" would come back on a phone as a prover with no
/// sheet showing.
///
/// **Off tears the prover's state down here, not in the widget that
/// flips it**, so every route to off gets the same teardown. The
/// dependency runs one way: this reads the prover's providers and they
/// never read this.
@Riverpod(keepAlive: true, name: 'experimentalProverProvider')
class ExperimentalProverNotifier extends _$ExperimentalProverNotifier {
  @override
  bool build() => false;

  void set(bool enabled) {
    if (enabled == state) return;
    state = enabled;
    if (!enabled) _tearDown();
  }

  /// Stop, then clear. The order matters: [ProverNotifier.stop] alone
  /// makes the interrupted run *publish* its prefix (cancellation is
  /// not supersession), and the generation bump in
  /// [ProverNotifier.clear] is what makes it drop that prefix instead.
  /// Closing the draft ends `draftCheck`, the numeric probe that runs
  /// on every construction change while a question is being built.
  void _tearDown() {
    ref.read(proverProvider.notifier)
      ..stop()
      ..clear();
    ref.read(questionDraftProvider.notifier).close();
    ref.read(proofHighlightProvider.notifier).clear();
  }
}
