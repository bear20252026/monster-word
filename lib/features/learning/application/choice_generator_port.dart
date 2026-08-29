import 'dart:math';

import 'package:word_app/features/learning/domain/choice_generator.dart';

export 'package:word_app/features/learning/domain/choice_generator.dart' show ChoiceCandidate;

/// Port: distractor choice generation for quizzes.
/// Presentation states depend on this abstraction, not on
/// `domain/choice_generator.dart` directly.
abstract class ChoiceGeneratorPort {
  List<ChoiceCandidate> generate({
    required ChoiceCandidate correct,
    required Iterable<ChoiceCandidate> candidates,
    Random? random,
  });
}
