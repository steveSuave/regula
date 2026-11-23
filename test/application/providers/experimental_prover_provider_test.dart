import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/persistence/construction_codec.dart';
import 'package:regula/application/providers/construction_provider.dart';
import 'package:regula/application/providers/experimental_prover_provider.dart';
import 'package:regula/application/providers/preferences_provider.dart';
import 'package:regula/application/providers/proof_highlight_provider.dart';
import 'package:regula/application/providers/prover_provider.dart';
import 'package:regula/application/providers/question_draft_provider.dart';
import 'package:regula/domain/prover/question_template.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Intent 003: the prover is an experimental feature, off by default.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;

  Future<ProviderContainer> containerWithPrefs({
    Map<String, Object> stored = const {},
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a fresh install has the prover off', () async {
    final container = await containerWithPrefs();
    expect(container.read(experimentalProverProvider), isFalse);
  });

  test('a stored opt-in wins on startup', () async {
    final container = await containerWithPrefs(
      stored: {ExperimentalProverNotifier.prefsKey: true},
    );
    expect(container.read(experimentalProverProvider), isTrue);
  });

  test('on is stored; off removes the key, like a fresh install', () async {
    final container = await containerWithPrefs();
    final notifier = container.read(experimentalProverProvider.notifier);

    notifier.set(true);
    expect(container.read(experimentalProverProvider), isTrue);
    expect(preferences.getBool(ExperimentalProverNotifier.prefsKey), isTrue);

    notifier.set(false);
    expect(container.read(experimentalProverProvider), isFalse);
    expect(
      preferences.containsKey(ExperimentalProverNotifier.prefsKey),
      isFalse,
    );
  });

  test('off mid-run stops the run and drops its result', () async {
    final container = await containerWithPrefs(
      stored: {ExperimentalProverNotifier.prefsKey: true},
    );
    // The fixture prover_provider_test's stop test uses: it does not
    // reach its fixpoint in one chunk, so the run is still in flight
    // after `prove` yields.
    final construction = decodeDocument(
      jsonDecode(
        File('test/fixtures/perp-true-unproved.rgl').readAsStringSync(),
      ) as Map<String, dynamic>,
    ).construction;
    container.read(constructionProvider.notifier).replace(construction);

    final pending = container.read(proverProvider.notifier).prove();
    expect(container.read(proverProvider), isA<ProverRunning>());

    container.read(experimentalProverProvider.notifier).set(false);
    await pending;

    expect(
      container.read(proverProvider),
      const ProverIdle(),
      reason:
          'a stop alone would publish the prefix as ProverReady; off '
          'must leave no prover state behind',
    );
  });

  test('off closes the question draft and empties the highlight', () async {
    final container = await containerWithPrefs(
      stored: {ExperimentalProverNotifier.prefsKey: true},
    );
    container.read(questionDraftProvider.notifier).open(QuestionTemplate.perp);
    container.read(proofHighlightProvider.notifier).show(['a', 'b']);

    container.read(experimentalProverProvider.notifier).set(false);

    expect(container.read(questionDraftProvider), isNull);
    expect(container.read(proofHighlightProvider), isEmpty);
  });
}
