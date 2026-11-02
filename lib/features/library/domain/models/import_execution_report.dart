abstract final class ImportFailureReasonCode {
  static const cancelled = 'cancelled';
  static const noSpace = 'no_space';
  static const permission = 'permission';
  static const duplicate = 'duplicate';
  static const unsupported = 'unsupported';
  static const corrupt = 'corrupt';
  static const invalid = 'invalid';
  static const file = 'file';
  static const database = 'database';
  static const network = 'network';
  static const authentication = 'authentication';
  static const system = 'system';
  static const ui = 'ui';
  static const temporaryCopy = 'temporary_copy';
  static const processing = 'processing';
}

class ImportFailureDetail {
  final String path;
  final String displayName;
  final String reason;

  const ImportFailureDetail({
    required this.path,
    required this.displayName,
    required this.reason,
  });

  Map<String, dynamic> toMap() {
    return {'path': path, 'displayName': displayName, 'reason': reason};
  }

  factory ImportFailureDetail.fromMap(Map<String, dynamic> map) {
    return ImportFailureDetail(
      path: (map['path'] as String?) ?? '',
      displayName: (map['displayName'] as String?) ?? '',
      reason: (map['reason'] as String?) ?? '',
    );
  }
}

/// A committed destination, never a provisional or rolled-back item.
class ImportCommittedItem {
  final int id;
  final String? uid;
  final String path;
  final String sourcePath;
  final bool isFolder;
  final bool isCatalog;
  final int? sizeBytes;

  const ImportCommittedItem({
    required this.id,
    this.uid,
    required this.path,
    required this.sourcePath,
    this.isFolder = false,
    this.isCatalog = false,
    this.sizeBytes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'uid': uid,
    'path': path,
    'sourcePath': sourcePath,
    'isFolder': isFolder,
    'isCatalog': isCatalog,
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
  };
  factory ImportCommittedItem.fromMap(Map<String, dynamic> map) =>
      ImportCommittedItem(
        id: (map['id'] as num).toInt(),
        uid: map['uid'] as String?,
        path: map['path'] as String,
        sourcePath: map['sourcePath'] as String,
        isFolder: map['isFolder'] == true,
        isCatalog: map['isCatalog'] == true,
        sizeBytes: (map['sizeBytes'] as num?)?.toInt(),
      );
}

class ImportExecutionReport {
  final String? sessionId;
  final List<ImportCommittedItem> committedItems;
  final List<ImportCommittedItem> destinations;
  final List<String> pendingSourcePaths;
  final bool isRolledBack;
  final bool retryBlocked;

  List<ImportCommittedItem> get committedFiles =>
      committedItems.where((item) => !item.isFolder).toList(growable: false);
  bool get hasCommittedFiles => committedItems.any((item) => !item.isFolder);

  final int totalItems;
  final int processedItems;
  final int failedItems;
  final int failureThresholdCount;
  final bool isCancelled;
  final List<ImportFailureDetail> failedEntries;

  const ImportExecutionReport({
    this.sessionId,
    this.committedItems = const [],
    this.destinations = const [],
    this.pendingSourcePaths = const [],
    this.isRolledBack = false,
    this.retryBlocked = false,
    required this.totalItems,
    required this.processedItems,
    required this.failedItems,
    required this.failureThresholdCount,
    this.isCancelled = false,
    this.failedEntries = const [],
  });

  bool get hasPartialFailure =>
      failedItems > 0 || (!isCancelled && pendingSourcePaths.isNotEmpty);
  bool get exceedsFailureThreshold => failedItems >= failureThresholdCount;

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'committedItems': committedItems.map((item) => item.toMap()).toList(),
      'destinations': destinations.map((item) => item.toMap()).toList(),
      'pendingSourcePaths': pendingSourcePaths,
      'isRolledBack': isRolledBack,
      'retryBlocked': retryBlocked,
      'totalItems': totalItems,
      'processedItems': processedItems,
      'failedItems': failedItems,
      'failureThresholdCount': failureThresholdCount,
      'isCancelled': isCancelled,
      'hasPartialFailure': hasPartialFailure,
      'exceedsFailureThreshold': exceedsFailureThreshold,
      'failedEntries': failedEntries.map((entry) => entry.toMap()).toList(),
    };
  }

  factory ImportExecutionReport.fromMap(Map<String, dynamic> map) {
    return ImportExecutionReport(
      sessionId: map['sessionId'] as String?,
      committedItems: (map['committedItems'] as List<dynamic>? ?? const [])
          .map(
            (value) => ImportCommittedItem.fromMap(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(),
      destinations: (map['destinations'] as List<dynamic>? ?? const [])
          .map(
            (value) => ImportCommittedItem.fromMap(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(),
      pendingSourcePaths:
          (map['pendingSourcePaths'] as List<dynamic>? ?? const [])
              .cast<String>(),
      isRolledBack: map['isRolledBack'] == true,
      retryBlocked: map['retryBlocked'] == true,
      totalItems: (map['totalItems'] as num?)?.toInt() ?? 0,
      processedItems: (map['processedItems'] as num?)?.toInt() ?? 0,
      failedItems: (map['failedItems'] as num?)?.toInt() ?? 0,
      failureThresholdCount:
          (map['failureThresholdCount'] as num?)?.toInt() ?? 0,
      isCancelled: map['isCancelled'] == true,
      failedEntries: (map['failedEntries'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ImportFailureDetail.fromMap)
          .toList(growable: false),
    );
  }

  ImportExecutionReport copyWith({
    String? sessionId,
    List<ImportCommittedItem>? committedItems,
    List<ImportCommittedItem>? destinations,
    List<String>? pendingSourcePaths,
    bool? isRolledBack,
    bool? retryBlocked,
    int? totalItems,
    int? processedItems,
    int? failedItems,
    int? failureThresholdCount,
    bool? isCancelled,
    List<ImportFailureDetail>? failedEntries,
  }) {
    return ImportExecutionReport(
      sessionId: sessionId ?? this.sessionId,
      committedItems: committedItems ?? this.committedItems,
      destinations: destinations ?? this.destinations,
      pendingSourcePaths: pendingSourcePaths ?? this.pendingSourcePaths,
      isRolledBack: isRolledBack ?? this.isRolledBack,
      retryBlocked: retryBlocked ?? this.retryBlocked,
      totalItems: totalItems ?? this.totalItems,
      processedItems: processedItems ?? this.processedItems,
      failedItems: failedItems ?? this.failedItems,
      failureThresholdCount:
          failureThresholdCount ?? this.failureThresholdCount,
      isCancelled: isCancelled ?? this.isCancelled,
      failedEntries: failedEntries ?? this.failedEntries,
    );
  }

  static const int defaultFailureThresholdCount = 5;
}
