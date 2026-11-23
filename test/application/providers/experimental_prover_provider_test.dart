import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/persistence/construction_codec.dart';
import 'package:regula/application/providers/construction_provider.dart';
import 'package:regula/application/providers/experimental_prover_provider.dart';
import 'package:regula/application/providers/proof_highlight_provider.dart';
import 'package:regula/application/providers/prover_provider.dart';
import 'package:regula/application/providers/question_draft_provider.dart';
import 'package:regula/domain/prover/question_template.dart';

/// Intents 003 and 007: the prover is an experimental feature, off on
/// every fresh load, and on is its panel being open.
void main() {
  ProviderContainer fresh() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('every fresh load has the prover off', () {
    expect(fresh().read(experimentalProverProvider), isFalse);
  });

  test('set flips it, and setting the same value is a no-op', () {
    final container = fresh();
    final notifier = container.read(experimentalProverProvider.notifier);
    notifier.set(true);
    expect(container.read(experimentalProverProvider), isTrue);
    notifier.set(true);
    expect(container.read(experimentalProverProvider), isTrue);
    notifier.set(false);
    expect(container.read(experimentalProverProvider), isFalse);
  });

  test('off mid-run stops the run and drops its result', () async {
    final container = fresh();
    container.read(experimentalProverProvider.notifier).set(true);
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
    final container = fresh();
    container.read(experimentalProverProvider.notifier).set(true);
    container.read(questionDraftProvider.notifier).open(QuestionTemplate.perp);
    container.read(proofHighlightProvider.notifier).show(['a', 'b']);

    container.read(experimentalProverProvider.notifier).set(false);

    expect(container.read(questionDraftProvider), isNull);
    expect(container.read(proofHighlightProvider), isEmpty);
  });
}
