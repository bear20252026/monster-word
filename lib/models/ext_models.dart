// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 模型层：翻译自 model/（v3.2 源码 9 个类）
// 文件：LoadDataType + BaseEvent + LoadDataCompleteEvent + LoadDataErrorEvent
//       + BaseListModel + LibraryModel + ListWordLearnModel + MessageModel + ZpkDownLoadManager

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'word_data_models.dart';
import 'learning_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LoadDataType（翻译自 LoadDataType.java）
// ─────────────────────────────────────────────────────────────────────────────

/// 加载类型常量
class LoadDataType {
  static const int loadRefresh = 1;
  static const int loadMore = 2;
  static const int loadRefreshNew = 3;

  LoadDataType._();
}

// ─────────────────────────────────────────────────────────────────────────────
// BaseEvent / LoadDataCompleteEvent / LoadDataErrorEvent
// 翻译自 model/base/BaseEvent.java + LoadDataCompleteEvent.java + LoadDataErrorEvent.java
// ─────────────────────────────────────────────────────────────────────────────

/// 事件基类（替代 EventBus 的 BaseEvent）
class BaseEvent {
  String eventKey;

  BaseEvent({this.eventKey = ''});
}

/// 数据加载完成事件
class LoadDataCompleteEvent extends BaseEvent {
  final int loadType;

  LoadDataCompleteEvent({required super.eventKey, required this.loadType});

  factory LoadDataCompleteEvent.build(String eventKey, int loadType) =>
      LoadDataCompleteEvent(eventKey: eventKey, loadType: loadType);
}

/// 数据加载失败事件
class LoadDataErrorEvent extends BaseEvent {
  final int loadType;
  final int resultCode;
  final String errorMsg;

  LoadDataErrorEvent({
    required super.eventKey,
    required this.loadType,
    required this.resultCode,
    this.errorMsg = '',
  });

  factory LoadDataErrorEvent.build(
    String eventKey,
    int loadType,
    int resultCode,
    String errorMsg,
  ) =>
      LoadDataErrorEvent(
        eventKey: eventKey,
        loadType: loadType,
        resultCode: resultCode,
        errorMsg: errorMsg,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// BaseListModel<T>（翻译自 model/base/BaseListModel.java）
// 原版用 EventBus 发事件，这里改为 ChangeNotifier + 回调
// ─────────────────────────────────────────────────────────────────────────────

/// 请求参数构建器（替代原版 RequestParams）
class RequestParams {
  final Map<String, String> _params = {};

  void put(String key, String value) => _params[key] = value;
  void add(String key, String value) => _params[key] = value;
  String? operator [](String key) => _params[key];
  Map<String, String> toMap() => Map.unmodifiable(_params);

  /// 拼接为 URL 查询字符串
  String toQueryString() =>
      _params.entries.map((e) => '${e.key}=${e.value}').join('&');
}

/// 列表数据模型基类（翻译自 BaseListModel.java）
///
/// 原版通过 EventBus 通知 UI，这里改为：
/// - [onLoadComplete] / [onLoadError] 回调
/// - [ChangeNotifier] 驱动 UI 刷新
///
/// 子类需实现：[getLoadParams], [getLoadMoreParams], [getLoadNewParams],
/// [commitMoreData], [commitRefreshNewData], [getTotalNum]
abstract class BaseListModel<T> {
  String eventKey = '';
  T? result;
  int pageNum = 10;
  bool hasMore = true;

  /// 事件回调（替代 EventBus）
  void Function(LoadDataCompleteEvent event)? onLoadComplete;
  void Function(LoadDataErrorEvent event)? onLoadError;

  void setEventKey(String key) => eventKey = key;
  T? getResult() => result;
  bool hasMoreData() => hasMore;
  void setPageNum(int n) => pageNum = n;

  // ── 子类必须实现 ──

  /// 初始加载参数
  RequestParams getLoadParams();

  /// 加载更多参数
  RequestParams getLoadMoreParams();

  /// 刷新新数据参数
  RequestParams getLoadNewParams();

  /// 合并更多数据
  void commitMoreData(T data);

  /// 合并刷新的新数据
  void commitRefreshNewData(T data);

  /// 当前数据条数
  int getTotalNum();

  // ── HTTP 加载 ──

  /// 从 JSON 解析结果（子类可覆盖）
  T parseResult(Map<String, dynamic> json);

  /// 初始加载
  Future<void> loadData() async {
    try {
      final params = getLoadParams();
      final uri = _buildUri(params);
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final json = _decodeJson(resp.body);
        final data = parseResult(json as Map<String, dynamic>);
        onLoadDataComplete(data);
      } else {
        onLoadDataFailure(resp.statusCode, '请求失败');
      }
    } catch (e) {
      onLoadDataFailure(-1, e.toString());
    }
  }

  /// 加载更多
  Future<void> loadMoreData() async {
    try {
      final params = getLoadMoreParams();
      final uri = _buildUri(params);
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final json = _decodeJson(resp.body);
        final data = parseResult(json as Map<String, dynamic>);
        onLoadMoreDataComplete(data);
      } else {
        onLoadMoreDataFailure(resp.statusCode, '请求失败');
      }
    } catch (e) {
      onLoadMoreDataFailure(-1, e.toString());
    }
  }

  /// 刷新新数据
  Future<void> loadNewData() async {
    try {
      final params = getLoadNewParams();
      final uri = _buildUri(params);
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final json = _decodeJson(resp.body);
        final data = parseResult(json as Map<String, dynamic>);
        onLoadNewDataComplete(data);
      } else {
        onLoadNewDataFailure(resp.statusCode, '请求失败');
      }
    } catch (e) {
      onLoadNewDataFailure(-1, e.toString());
    }
  }

  // ── 内部回调 ──

  void onLoadDataComplete(T data) {
    result = data;
    hasMore = getTotalNum() >= pageNum;
    onLoadComplete?.call(LoadDataCompleteEvent.build(eventKey, LoadDataType.loadRefresh));
  }

  void onLoadDataFailure(int code, String msg) {
    onLoadError?.call(LoadDataErrorEvent.build(eventKey, LoadDataType.loadRefresh, code, msg));
  }

  void onLoadMoreDataComplete(T data) {
    commitMoreData(data);
    onLoadComplete?.call(LoadDataCompleteEvent.build(eventKey, LoadDataType.loadMore));
  }

  void onLoadMoreDataFailure(int code, String msg) {
    onLoadError?.call(LoadDataErrorEvent.build(eventKey, LoadDataType.loadMore, code, msg));
  }

  void onLoadNewDataComplete(T data) {
    commitRefreshNewData(data);
    onLoadComplete?.call(LoadDataCompleteEvent.build(eventKey, LoadDataType.loadRefreshNew));
  }

  void onLoadNewDataFailure(int code, String msg) {
    onLoadError?.call(LoadDataErrorEvent.build(eventKey, LoadDataType.loadRefreshNew, code, msg));
  }

  // ── 工具方法 ──

  Uri _buildUri(RequestParams params) {
    // 默认基类实现：拼接查询参数，子类可覆盖
    throw UnimplementedError('子类需覆盖 _buildUri 或直接覆盖 loadData 系列方法');
  }

  static dynamic _decodeJson(String body) {
    // 简单 JSON 解码，依赖 dart:convert
    return body.isNotEmpty ? _jsonDecode(body) : null;
  }
}

dynamic _jsonDecode(String s) {
  // 延迟引入 dart:convert 避免循环
  return const JsonDecoder().convert(s);
}

// ─────────────────────────────────────────────────────────────────────────────
// LibraryModel（翻译自 model/LibraryModel.java）
// 原版含 Android UI（ProgressDialog），这里只保留业务逻辑
// ─────────────────────────────────────────────────────────────────────────────

/// 词书处理监听器（替代原版 LibraryDealListener）
abstract class LibraryDealListener {
  void onStartDownloadLibrary();
  void onChangedLibSuccess(Map<String, dynamic> libraryData);
  void onChangedLibFail(String msg, int errorCode);
  void onDownloadProgressChanged(int percent);
  void onProgressMsgChanged(String msg);
}

/// 词书下载/更换模型（翻译自 LibraryModel.java）
///
/// 负责：下载词书 zip → 解压 → 加密 → 更换本地词书
/// 原版用 Android Handler 处理异步，这里改为 async/await + 回调
class LibraryModel {
  static const int errorCommon = 1;
  static const int errorMemoryNotEnough = 2;
  static const int errorCanceled = 3;
  static const int errorUnzip = 4;

  final LibraryDealListener? listener;

  LibraryModel({this.listener});

  /// 更换词书（从 JSONObject）
  Future<void> changedLib(Map<String, dynamic> libData, bool isUpdate) async {
    await _startDownloadLibrary(libData, isUpdate);
  }

  Future<void> _startDownloadLibrary(
    Map<String, dynamic> libData,
    bool isUpdate,
  ) async {
    if (libData.isEmpty) return;

    // 通知 UI 开始下载
    listener?.onStartDownloadLibrary();

    // TODO: 实际下载逻辑需要接入项目的网络层和文件系统
    // 原版流程：
    // 1. 下载 zip 到临时文件
    // 2. 检查存储空间
    // 3. 解压
    // 4. 加密数据库
    // 5. 切换词书
    // 这里保留框架，具体实现待接入项目基础设施
  }

  /// 检查词书是否已存在本地
  static bool isLibraryExistInLocal(
    String dbDir,
    Map<String, dynamic> libData,
  ) {
    final code = libData['code'] as String? ?? '';
    if (code.isEmpty) return false;
    // 实际检查需要 path_provider，这里保留接口
    return false;
  }

  /// 取消当前任务
  void cancelTask() {
    _downloadLibraryFail('', errorCanceled);
  }

  void _downloadLibraryFail(String msg, int errorCode) {
    listener?.onChangedLibFail(msg, errorCode);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ListWordLearnModel（翻译自 model/ListWordLearnModel.java）
// 管理单词列表的前一个/当前/下一个导航
// ─────────────────────────────────────────────────────────────────────────────

/// 单词列表学习模型（翻译自 ListWordLearnModel.java）
///
/// 管理滑动翻页时的 pre/cur/next 三词缓存，
/// 并在切换时异步加载 zpk 数据
class ListWordLearnModel {
  final List<BBListWord> originalWordList;
  int _curIndex;
  bool _loop = false;

  BBListWord? _preWordData;
  BBListWord? _curWordData;
  BBListWord? _nextWordData;

  int _preIndex = 0;
  int _nexIndex = 0;

  ListWordLearnModel(this.originalWordList, int startIndex)
      : _curIndex = startIndex;

  int get curIndex => _curIndex;
  int get totalCount => originalWordList.length;
  List<BBListWord> get wordList => originalWordList;

  /// 设置是否循环翻页
  set loop(bool value) => _loop = value;

  bool get isEndPos =>
      originalWordList.isEmpty || _curIndex >= originalWordList.length - 1;

  bool get isStartPos => _curIndex == 0;

  /// 当前单词的基础信息
  BBWordBaseInfo? getCurWordData() {
    return _curWordData?.wordBaseInfo;
  }

  /// 初始化三词缓存
  void initLoadData() {
    _preWordData = _getWordByIndex(_curIndex - 1);
    _curWordData = _getWordByIndex(_curIndex);
    _nextWordData = _getWordByIndex(_curIndex + 1);
  }

  /// 向前翻页（返回当前词的基础信息）
  BBWordBaseInfo? preWord() {
    if (_curIndex <= 0 && !_loop) return null;

    _curIndex--;
    if (_curIndex < 0) _curIndex = originalWordList.length - 1;

    _preIndex = _curIndex - 1;
    if (_preIndex < 0) _preIndex = originalWordList.length - 1;

    _nexIndex = _curIndex + 1;
    if (_nexIndex >= originalWordList.length) _nexIndex = 0;

    _nextWordData = _curWordData;
    _curWordData = _preWordData;
    _preWordData = null;

    _loadData(_preIndex);
    return getCurWordData();
  }

  /// 向后翻页（返回当前词的基础信息）
  BBWordBaseInfo? nextWord() {
    if (_curIndex + 1 >= originalWordList.length && !_loop) return null;

    _curIndex++;
    if (_curIndex >= originalWordList.length) _curIndex = 0;

    _preWordData = _curWordData;
    _curWordData = _nextWordData;

    _preIndex = _curIndex - 1;
    if (_preIndex < 0) _preIndex = originalWordList.length - 1;

    _nexIndex = _curIndex + 1;
    if (_nexIndex >= originalWordList.length) _nexIndex = 0;

    _nextWordData = null;
    _loadData(_nexIndex);
    return getCurWordData();
  }

  void _loadData(int index) {
    if (originalWordList.isEmpty ||
        index < 0 ||
        index >= originalWordList.length) {
      return;
    }

    final word = originalWordList[index];

    if (_curIndex == index) {
      _curWordData = word;
    } else if (_preIndex == index) {
      _preWordData = word;
      // 异步加载前一词的 zpk 数据
      _updateWordBaseInfo(word);
      final prevIdx = _preIndex > 0
          ? _preIndex - 1
          : originalWordList.length - 1;
      _updateWordBaseInfo(originalWordList[prevIdx]);
    } else if (_nexIndex == index) {
      _nextWordData = word;
      _updateWordBaseInfo(word);
      if (_nexIndex < originalWordList.length - 1) {
        _updateWordBaseInfo(originalWordList[_nexIndex + 1]);
      } else {
        _updateWordBaseInfo(originalWordList[0]);
      }
    }
  }

  /// 异步加载 zpk 数据填充 wordBaseInfo
  /// TODO: 接入项目的 ZpkUtils
  void _updateWordBaseInfo(BBListWord word) {
    if (word.zpkName.isEmpty || word.wordBaseInfo != null) return;
    // 原版调用 ZpkUtils.downloadZpk → 解析 → 设置 wordBaseInfo
    // 需要接入项目的 zpk 工具层
  }

  BBListWord? _getWordByIndex(int i) {
    if (originalWordList.isEmpty || i < 0 || i >= originalWordList.length) {
      return null;
    }
    return originalWordList[i];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MessageModel（翻译自 model/MessageModel.java）
// 消息/通知列表模型，继承 BaseListModel
// ─────────────────────────────────────────────────────────────────────────────

/// 消息数据项（简化版，原版依赖 MessageData bean）
class MessageData {
  final String time;
  final Map<String, dynamic> raw;

  MessageData({this.time = '', this.raw = const {}});

  factory MessageData.fromJson(Map<String, dynamic> json) => MessageData(
        time: json['time']?.toString() ?? '',
        raw: json,
      );
}

/// 消息数据集（简化版，原版依赖 MessageSetData bean）
class MessageSetData {
  final List<MessageData> items;

  MessageSetData({this.items = const []});

  int get count => items.length;

  MessageData? getItem(int index) {
    if (index < 0 || index >= items.length) return null;
    return items[index];
  }

  /// 追加刷新的新数据
  void addRefreshNewData(MessageSetData newData) {
    // 原版逻辑：newData 插入到头部
  }

  /// 追加更多数据
  void addMoreData(MessageSetData moreData) {
    // 原版逻辑：moreData 追加到尾部
  }

  factory MessageSetData.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List? ?? [];
    return MessageSetData(
      items: list
          .map((e) => MessageData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 消息列表模型（翻译自 MessageModel.java）
///
/// 继承 BaseListModel<MessageSetData>，支持刷新/加载更多
class MessageModel extends BaseListModel<MessageSetData> {
  MessageModel() {
    pageNum = 10;
  }

  @override
  RequestParams getLoadParams() {
    final params = RequestParams();
    params.put('type', 'news');
    params.put('action', 'refresh');
    return params;
  }

  @override
  RequestParams getLoadMoreParams() {
    final params = RequestParams();
    params.put('type', 'news');
    params.put('action', 'loadmore');
    final data = result;
    if (data != null && data.count > 0) {
      final lastItem = data.getItem(data.count - 1);
      if (lastItem != null) {
        params.put('time', lastItem.time);
      }
    }
    return params;
  }

  @override
  RequestParams getLoadNewParams() {
    final params = RequestParams();
    params.put('type', 'news');
    params.put('action', 'refresh');
    final data = result;
    if (data != null && data.count > 0) {
      final firstItem = data.getItem(0);
      if (firstItem != null) {
        params.put('time', firstItem.time);
      }
    }
    return params;
  }

  @override
  void commitRefreshNewData(MessageSetData newData) {
    if (result != null) {
      result?.addRefreshNewData(newData);
    } else {
      result = newData;
    }
  }

  @override
  void commitMoreData(MessageSetData moreData) {
    if (moreData.count > 0) {
      hasMore = moreData.count >= pageNum;
    }
    if (result != null) {
      result?.addMoreData(moreData);
    }
  }

  @override
  int getTotalNum() {
    final data = result;
    return data != null ? data.count : 0;
  }

  @override
  MessageSetData parseResult(Map<String, dynamic> json) {
    return MessageSetData.fromJson(json);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ZpkDownLoadManager（翻译自 model/ZpkDownLoadManager.java）
// 并发下载 zpk 文件的管理器
// ─────────────────────────────────────────────────────────────────────────────

/// zpk 批量下载监听器（替代原版 ZpkListDownLoadListener）
abstract class ZpkListDownLoadListener {
  void onDownloadStart();
  void onDownloadComplete();
  void onDownloadFileResult(String zpkName, bool success);
  void onProgressChanged(int current, int total);
}

/// zpk 并发下载管理器（翻译自 ZpkDownLoadManager.java）
///
/// 原版用 ExecutorService(6线程) + Handler 消息队列，
/// 改为 Dart async + 最大并发数控制
class ZpkDownLoadManager {
  static const int _maxConcurrent = 6;

  final Queue<String> _downloadQueue = Queue<String>();
  int _totalCount = 0;
  bool _canceled = false;

  /// 批量下载 zpk 文件
  ///
  /// [zpkNames] 待下载的 zpk 文件名列表
  /// [listener] 下载进度回调
  Future<void> downloadZpks(
    List<String> zpkNames,
    ZpkListDownLoadListener listener,
  ) async {
    if (zpkNames.isEmpty) {
      listener.onDownloadComplete();
      return;
    }

    _downloadQueue.clear();
    _downloadQueue.addAll(zpkNames);
    _totalCount = _downloadQueue.length;
    _canceled = false;

    listener.onDownloadStart();

    // 启动最多 maxConcurrent 个并发任务
    final initialBatch = _maxConcurrent < _totalCount
        ? _maxConcurrent
        : _totalCount;
    for (var i = 0; i < initialBatch; i++) {
      _startNextDownload();
    }
  }

  void _startNextDownload() {
    if (_canceled || _downloadQueue.isEmpty) return;

    _downloadQueue.removeFirst();

    // TODO: 接入项目的 ZpkUtils.downloadZpk
    // 原版流程：
    // 1. 检查本地是否已有该 zpk → 直接回调成功
    // 2. 否则下载 → 回调成功/失败
  }

  /// 取消所有下载任务
  void cancelTask() {
    _canceled = true;
  }
}
