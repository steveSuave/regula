import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'preferences_provider.dart';
import 'proof_highlight_provider.dart';
import 'prover_provider.dart';
import 'question_draft_provider.dart';

part 'experimental_prover_provider.g.dart';

/// Whether the prover's surfaces exist at all: "Experimental: prover" in
/// the geometry menu, off on a fresh install (DECISIONS §"The prover is
/// behind a device preference").
///
/// A preference of the device, beside [themeModeProvider], not of the
/// document: a file opens the same whoever has the prover on. Writes are
/// fire-and-forget like the theme's, and off is stored as no key at all,
/// so an opted-out device and a fresh one hold the same thing.
///
/// **Off tears the prover's state down here, not in the widget that
/// flips it**, so every route to off gets the same teardown. The
/// dependency runs one way: this reads the prover's providers and they
/// never read this.
@Riverpod(keepAlive: true, name: 'experimentalProverProvider')
class ExperimentalProverNotifier extends _$ExperimentalProverNotifier {
  static const String prefsKey = 'experimental.prover';

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(prefsKey) ?? false;

  void set(bool enabled) {
    if (enabled == state) return;
    state = enabled;
    final preferences = ref.read(sharedPreferencesProvider);
    unawaited(
      enabled
          ? preferences.setBool(prefsKey, true)
          : preferences.remove(prefsKey),
    );
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
