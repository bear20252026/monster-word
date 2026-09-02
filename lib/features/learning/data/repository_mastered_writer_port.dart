import 'package:word_app/app/service_locator.dart';
import 'package:word_app/features/learning/data/mastered_repository.dart';
import 'package:word_app/features/learning/application/mastered_writer_port.dart';

/// Adapts [MasteredRepository] (legacy repositories) to [MasteredWriterPort] (application layer).
class RepositoryMasteredWriterPort implements MasteredWriterPort {
  final MasteredRepository _repository;

  RepositoryMasteredWriterPort(this._repository);

  factory RepositoryMasteredWriterPort.fromServiceLocator() => RepositoryMasteredWriterPort(sl<MasteredRepository>());

  @override
  Future<void> toggleMastered(String word) => _repository.toggleMastered(word);
}
