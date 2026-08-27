import '../../../models/bb_word_process.dart';
import '../../../models/word.dart';

/// 正式复习词条的详情页适配器。
///
/// [BBWordProcess] 是复习会话的轻量过程模型；词典详情页仍以 [Word] 为输入。
/// 该扩展集中两者之间的明确字段映射，避免路由页面重复维护默认字段。
extension ReviewWordDetails on BBWordProcess {
  Word toDictionaryWord() => Word(
    id: wordId,
    word: word,
    mainWord: word,
    interpret: interpret,
    usPron: usPron,
    ukPron: ukPron,
    example: example,
  );
}
