enum LibraryIntegrityIssueType {
  orphanStorageRef,
  duplicatePrimaryStorageRef,
  missingTagFacet,
  missingTagParent,
  tagParentFacetMismatch,
  tagCycle,
  invalidTagHierarchy,
  incorrectTagUsageCount,
  invalidLastViewedItem,
  multiplyOwnedMediaItem,
  missingUid,
  missingMediaItemCollectionLink,
}

enum LibraryIntegrityEntityType {
  collection,
  mediaItem,
  tag,
  tagFacet,
  storageRef,
}

class LibraryIntegrityIssue {
  const LibraryIntegrityIssue({
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.isRepairable,
    this.entityUid,
    this.relatedEntityIds = const <int>[],
  });

  final LibraryIntegrityIssueType type;
  final LibraryIntegrityEntityType entityType;
  final int entityId;
  final String? entityUid;
  final bool isRepairable;
  final List<int> relatedEntityIds;
}

class LibraryIntegrityReport {
  const LibraryIntegrityReport(this.issues);

  final List<LibraryIntegrityIssue> issues;

  bool get isHealthy => issues.isEmpty;

  int get repairableCount => issues.where((issue) => issue.isRepairable).length;

  int countByType(LibraryIntegrityIssueType type) =>
      issues.where((issue) => issue.type == type).length;
}

class LibraryIntegrityRepairResult {
  const LibraryIntegrityRepairResult({
    required this.before,
    required this.after,
    required this.changedRecordCount,
  });

  final LibraryIntegrityReport before;
  final LibraryIntegrityReport after;
  final int changedRecordCount;
}
