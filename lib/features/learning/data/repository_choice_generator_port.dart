import 'dart:math';

import '../application/choice_generator_port.dart';
import '../domain/choice_generator.dart';

/// Adapts [ChoiceGenerator] (domain) to [ChoiceGeneratorPort] (application layer).
class RepositoryChoiceGeneratorPort implements ChoiceGeneratorPort {
  const RepositoryChoiceGeneratorPort();

  @override
  List<ChoiceCandidate> generate({
    required ChoiceCandidate correct,
    required Iterable<ChoiceCandidate> candidates,
    Random? random,
  }) {
    return ChoiceGenerator.generate(
      correct: correct,
      candidates: candidates,
      random: random,
    );
  }
}
