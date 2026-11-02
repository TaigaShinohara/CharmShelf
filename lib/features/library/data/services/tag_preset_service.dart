import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:isar/isar.dart';

import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/services/import_safety_policy.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';

class TagPresetService {
  static const String exchangeFormat = 'tagshelf-charms';
  static const int exchangeVersion = 1;

  final Isar _isar;
  final _TagPresetFileIo _fileIo;
  final _TagPresetParser _parser;
  late final _TagPresetPersistence _persistence;

  TagPresetService(this._isar)
    : _fileIo = const _TagPresetFileIo(),
      _parser = const _TagPresetParser() {
    _persistence = _TagPresetPersistence(_isar);
  }

  /// 標準的なタグセットを作成する
  Future<int> createStandardPresets({String localeCode = 'ja'}) async {
    final useEnglish = localeCode.toLowerCase().startsWith('en');
    final facetNames = useEnglish
        ? const [
            'Content type',
            'Genre',
            'Status',
            'Vibe',
            'Language / Region',
            'Creator',
            'Uncategorized',
          ]
        : const ['コンテンツタイプ', 'ジャンル', '状態', '雰囲気', '言語/地域', '作者', '未分類'];

    await createDefaultFacets(localeCode: localeCode);
    final typeFacet = await _ensureFacet(facetNames[0]);
    final genreFacet = await _ensureFacet(facetNames[1]);
    final statusFacet = await _ensureFacet(facetNames[2]);
    final vibeFacet = await _ensureFacet(facetNames[3]);
    final langFacet = await _ensureFacet(facetNames[4]);
    final authorFacet = await _ensureFacet(facetNames[5]);

    final presets = useEnglish
        ? [
            _TagPreset('Illustration', typeFacet.id, null),
            _TagPreset('Comics', typeFacet.id, null),
            _TagPreset('Photo', typeFacet.id, null),
            _TagPreset('Screenshot', typeFacet.id, null),
            _TagPreset('Novel', typeFacet.id, null),
            _TagPreset('Article', typeFacet.id, null),
            _TagPreset('Proposal', typeFacet.id, null),
            _TagPreset('Movie', typeFacet.id, null),
            _TagPreset('Animation', typeFacet.id, null),
            _TagPreset('Music', typeFacet.id, null),
            _TagPreset(
              'Audio catalog',
              typeFacet.id,
              null,
              legacyName: 'Audio chain',
            ),
            _TagPreset('Language learning', typeFacet.id, null),
            _TagPreset('Fantasy', genreFacet.id, null),
            _TagPreset('Science fiction', genreFacet.id, null),
            _TagPreset('Mystery', genreFacet.id, null),
            _TagPreset('Horror', genreFacet.id, null),
            _TagPreset('Action', genreFacet.id, null),
            _TagPreset('Comedy', genreFacet.id, null),
            _TagPreset('Slice of life', genreFacet.id, null),
            _TagPreset('Romance', genreFacet.id, null),
            _TagPreset('Business', genreFacet.id, null),
            _TagPreset('Academic', genreFacet.id, null),
            _TagPreset('Unread', statusFacet.id, null),
            _TagPreset('In progress', statusFacet.id, null),
            _TagPreset('Completed', statusFacet.id, null),
            _TagPreset('Read later', statusFacet.id, null),
            _TagPreset('Needs organizing', statusFacet.id, null),
            _TagPreset('Keep', statusFacet.id, null),
            _TagPreset('Japanese style', vibeFacet.id, null),
            _TagPreset('Retro', vibeFacet.id, null),
            _TagPreset('Cyberpunk', vibeFacet.id, null),
            _TagPreset('Dark', vibeFacet.id, null),
            _TagPreset('Bright', vibeFacet.id, null),
            _TagPreset('Fantasy', vibeFacet.id, null),
            _TagPreset('Japanese', langFacet.id, null),
            _TagPreset('English', langFacet.id, null),
            _TagPreset('Translated', langFacet.id, null),
            _TagPreset('Osamu Tezuka', authorFacet.id, null),
            _TagPreset('Akira Toriyama', authorFacet.id, null),
            _TagPreset('Eiichiro Oda', authorFacet.id, null),
            _TagPreset('Makoto Shinkai', authorFacet.id, null),
            _TagPreset('Hayao Miyazaki', authorFacet.id, null),
            _TagPreset('Short form', null, null),
            _TagPreset('Long form', null, null),
            _TagPreset(
              'Catalog collection',
              null,
              null,
              legacyName: 'Chain collection',
            ),
          ]
        : [
            // --- コンテンツタイプ ---
            _TagPreset('イラスト', typeFacet.id, null),
            _TagPreset('漫画', typeFacet.id, null),
            _TagPreset('写真', typeFacet.id, null),
            _TagPreset('スクリーンショット', typeFacet.id, null),
            _TagPreset('小説', typeFacet.id, null),
            _TagPreset('記事', typeFacet.id, null),
            _TagPreset('企画書', typeFacet.id, null),
            _TagPreset('映画', typeFacet.id, null),
            _TagPreset('アニメ', typeFacet.id, null),
            _TagPreset('音楽', typeFacet.id, null),
            _TagPreset('音声カタログ', typeFacet.id, null, legacyName: '音声チェイン'),
            _TagPreset('語学学習', typeFacet.id, null),

            // --- ジャンル ---
            _TagPreset('ファンタジー', genreFacet.id, null),
            _TagPreset('SF', genreFacet.id, null),
            _TagPreset('ミステリー', genreFacet.id, null),
            _TagPreset('ホラー', genreFacet.id, null),
            _TagPreset('アクション', genreFacet.id, null),
            _TagPreset('コメディ', genreFacet.id, null),
            _TagPreset('日常', genreFacet.id, null),
            _TagPreset('ロマンス', genreFacet.id, null),
            _TagPreset('ビジネス', genreFacet.id, null),
            _TagPreset('学術', genreFacet.id, null),

            // --- 状態 (管理用) ---
            _TagPreset('未読', statusFacet.id, null),
            _TagPreset('視聴中', statusFacet.id, null),
            _TagPreset('読了', statusFacet.id, null),
            _TagPreset('積読', statusFacet.id, null),
            _TagPreset('要整理', statusFacet.id, null),
            _TagPreset('保存版', statusFacet.id, null),

            // --- 雰囲気 (Vibe) ---
            _TagPreset('和風', vibeFacet.id, null),
            _TagPreset('レトロ', vibeFacet.id, null),
            _TagPreset('サイバーパンク', vibeFacet.id, null),
            _TagPreset('ダーク', vibeFacet.id, null),
            _TagPreset('明るい', vibeFacet.id, null),
            _TagPreset('ファンタジー', vibeFacet.id, null),

            // --- 言語/地域 ---
            _TagPreset('日本語', langFacet.id, null),
            _TagPreset('英語', langFacet.id, null),
            _TagPreset('翻訳済み', langFacet.id, null),

            // --- 作者 (サンプル) ---
            _TagPreset('手塚治虫', authorFacet.id, null),
            _TagPreset('鳥山明', authorFacet.id, null),
            _TagPreset('尾田栄一郎', authorFacet.id, null),
            _TagPreset('新海誠', authorFacet.id, null),
            _TagPreset('宮崎駿', authorFacet.id, null),

            // --- その他（未分類） ---
            _TagPreset('短編', null, null),
            _TagPreset('長編', null, null),
            _TagPreset('カタログ集', null, null, legacyName: 'チェイン集'),
          ];

    var createdCount = 0;
    final defaultFacet = await _ensureFacet(facetNames[6]);

    await _isar.writeTxn(() async {
      for (final preset in presets) {
        final facetId = preset.facetId ?? defaultFacet.id;
        final key = Tag.buildKey(facetId, preset.name);
        final existing = await _isar.tags.filter().keyEqualTo(key).findFirst();
        if (preset.legacyName != null) {
          // The new display name may already belong to a user's own charm.
          if (existing != null) continue;
          final legacyKey = Tag.buildKey(facetId, preset.legacyName!);
          final legacy = await _isar.tags
              .filter()
              .keyEqualTo(legacyKey)
              .findFirst();
          // Preserve the user's legacy charm, including its name, color,
          // hierarchy, and assignments. Do not create a second preset.
          if (legacy != null) continue;
        }
        if (existing == null) {
          final tag = Tag()
            ..key = key
            ..name = preset.name
            ..facetId = facetId
            ..level = 100
            ..ancestorIds = []
            ..createdAt = DateTime.now();

          await _isar.tags.put(tag);
          createdCount++;
        } else {
          // カラーをクリア
          if (existing.colorValue != null) {
            existing.colorValue = null;
            await _isar.tags.put(existing);
          }
        }
      }
    });

    return createdCount;
  }

  Future<TagPresetImportResult?> importPresetsFromFile() async {
    final jsonString = await _fileIo.pickPresetFileContent();
    if (jsonString == null) {
      return null;
    }
    return importPresetsFromJsonString(jsonString);
  }

  Future<String?> pickPresetFileContent() async {
    return _fileIo.pickPresetFileContent();
  }

  Future<TagPresetImportResult> importPresetsFromJsonString(
    String jsonString, {
    TagPresetConflictPolicy conflictPolicy =
        TagPresetConflictPolicy.keepExisting,
  }) async {
    try {
      final data = _parser.decodeJsonString(jsonString);
      return await _persistence.importData(
        data,
        conflictPolicy: conflictPolicy,
      );
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError.validation('Invalid JSON: $e');
    }
  }

  Future<TagPresetImportResult> importPresetsFromSimplifiedText(
    String text, {
    TagPresetConflictPolicy conflictPolicy =
        TagPresetConflictPolicy.keepExisting,
  }) async {
    final data = _parser.parseSimplifiedText(text);
    return _persistence.importData(data, conflictPolicy: conflictPolicy);
  }

  Future<TagPresetImportPreview> buildImportPreviewFromJsonString(
    String jsonString, {
    TagPresetConflictPolicy conflictPolicy =
        TagPresetConflictPolicy.keepExisting,
  }) async {
    final data = _parser.decodeJsonString(jsonString);
    return _persistence.buildPreview(data, conflictPolicy: conflictPolicy);
  }

  Future<TagPresetImportPreview> buildImportPreviewFromSimplifiedText(
    String text, {
    TagPresetConflictPolicy conflictPolicy =
        TagPresetConflictPolicy.keepExisting,
  }) async {
    final data = _parser.parseSimplifiedText(text);
    return _persistence.buildPreview(data, conflictPolicy: conflictPolicy);
  }

  /// 現在のチャーム定義を、端末固有IDを含まない交換用JSONへ変換する。
  Future<TagPresetExportData> exportPresetsAsJsonString({
    int? facetId,
    DateTime? exportedAt,
  }) async {
    final effectiveExportedAt = exportedAt ?? DateTime.now();
    final allFacets = await _isar.tagFacets.where().findAll();
    final selectedFacets =
        allFacets
            .where((facet) => facetId == null || facet.id == facetId)
            .toList()
          ..sort((a, b) {
            final order = a.sortOrder.compareTo(b.sortOrder);
            return order != 0 ? order : a.name.compareTo(b.name);
          });
    if (selectedFacets.isEmpty) {
      throw AppError.validation('No charm categories to export');
    }

    final selectedFacetIds = selectedFacets.map((facet) => facet.id).toSet();
    final allTags = await _isar.tags.where().findAll();
    final selectedTags = allTags
        .where((tag) => selectedFacetIds.contains(tag.facetId))
        .toList();
    final tagById = {for (final tag in allTags) tag.id: tag};
    final facetNameById = {for (final facet in allFacets) facet.id: facet.name};

    final tagData = <TagPresetTagData>[];
    for (final tag in selectedTags) {
      final currentFacetId = tag.facetId;
      final facetName = currentFacetId == null
          ? null
          : facetNameById[currentFacetId];
      if (facetName == null) {
        throw AppError.validation(
          'Charm "${tag.name}" references a missing category',
        );
      }

      String? parentName;
      final expectedAncestors = <int>[];
      final visited = <int>{tag.id};
      if (tag.parentId != null) {
        final parent = tagById[tag.parentId];
        if (parent == null || parent.facetId != currentFacetId) {
          throw AppError.validation(
            'Charm "${tag.name}" references an invalid parent',
          );
        }
        parentName = parent.name;

        var current = parent;
        while (true) {
          if (!visited.add(current.id)) {
            throw AppError.validation('Circular charm hierarchy detected');
          }
          expectedAncestors.add(current.id);
          if (expectedAncestors.length >
              ImportSafetyPolicy.maxRelativePathDepth) {
            throw AppError.validation('Charm hierarchy is too deep');
          }
          final nextParentId = current.parentId;
          if (nextParentId == null) break;
          final nextParent = tagById[nextParentId];
          if (nextParent == null || nextParent.facetId != currentFacetId) {
            throw AppError.validation(
              'Charm "${tag.name}" references an invalid ancestor',
            );
          }
          current = nextParent;
        }
        if (tag.level != parent.level + 1) {
          throw AppError.validation(
            'Charm "${tag.name}" has an inconsistent hierarchy level',
          );
        }
      }
      if (!_sameIntList(tag.ancestorIds, expectedAncestors)) {
        throw AppError.validation(
          'Charm "${tag.name}" has inconsistent ancestor data',
        );
      }
      tagData.add(
        TagPresetTagData(
          tag.name,
          facetName: facetName,
          parentName: parentName,
          level: tag.level,
          colorValue: tag.colorValue,
          isHidden: tag.isHidden,
          hasParentName: true,
          hasLevel: true,
          hasColorValue: true,
          hasIsHidden: true,
        ),
      );
    }
    tagData.sort((a, b) {
      final facetOrder = a.facetName!.compareTo(b.facetName!);
      if (facetOrder != 0) return facetOrder;
      final levelOrder = (a.level ?? 100).compareTo(b.level ?? 100);
      return levelOrder != 0 ? levelOrder : a.name.compareTo(b.name);
    });

    final data = TagPresetImportData(
      facets: selectedFacets
          .map(
            (facet) => TagPresetFacetData(
              facet.name,
              colorValue: facet.colorValue,
              sortOrder: facet.sortOrder,
              hasColorValue: true,
              hasSortOrder: true,
            ),
          )
          .toList(),
      tags: tagData,
      requireSelfContainedParents: true,
    );
    _parser.validateData(data);

    final document = <String, dynamic>{
      'format': exchangeFormat,
      'version': exchangeVersion,
      'exportedAt': effectiveExportedAt.toUtc().toIso8601String(),
      'categories': data.facets
          .map(
            (facet) => {
              'name': facet.name,
              'color': _encodeColor(facet.colorValue),
              'sortOrder': facet.sortOrder,
            },
          )
          .toList(),
      'charms': data.tags
          .map(
            (tag) => {
              'category': tag.facetName,
              'name': tag.name,
              'parent': tag.parentName,
              'level': tag.level,
              'color': _encodeColor(tag.colorValue),
              'hidden': tag.isHidden,
            },
          )
          .toList(),
    };
    final timestamp = effectiveExportedAt.toLocal();
    final stamp = [
      timestamp.year.toString().padLeft(4, '0'),
      timestamp.month.toString().padLeft(2, '0'),
      timestamp.day.toString().padLeft(2, '0'),
      '-',
      timestamp.hour.toString().padLeft(2, '0'),
      timestamp.minute.toString().padLeft(2, '0'),
    ].join();
    return TagPresetExportData(
      jsonString: const JsonEncoder.withIndent('  ').convert(document),
      fileName: 'tagshelf-charms-$stamp.json',
      facetCount: data.facets.length,
      tagCount: data.tags.length,
    );
  }

  /// システムの保存先選択UIを表示して交換用JSONを書き出す。
  Future<TagPresetExportResult?> exportPresetsToFile({
    int? facetId,
    String? dialogTitle,
  }) async {
    final data = await exportPresetsAsJsonString(facetId: facetId);
    final bytes = Uint8List.fromList(utf8.encode('${data.jsonString}\n'));
    final path = await _fileIo.savePresetFile(
      bytes: bytes,
      fileName: data.fileName,
      dialogTitle: dialogTitle,
    );
    if (path == null) return null;
    return TagPresetExportResult(
      path: path,
      facetCount: data.facetCount,
      tagCount: data.tagCount,
    );
  }

  static String? _encodeColor(int? value) {
    if (value == null) return null;
    return '#${value.toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  static bool _sameIntList(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  TagPresetImportData parseSimplifiedText(String text) {
    return _parser.parseSimplifiedText(text);
  }

  List<TagPresetValidationIssue> validateSimplifiedText(String text) {
    return _parser.validateSimplifiedText(text);
  }

  /// デフォルトのFacetテンプレートを作成する
  Future<void> createDefaultFacets({String localeCode = 'ja'}) async {
    final names = localeCode.toLowerCase().startsWith('en')
        ? const [
            'Content type',
            'Genre',
            'Status',
            'Vibe',
            'Language / Region',
            'Creator',
            'Uncategorized',
          ]
        : const ['コンテンツタイプ', 'ジャンル', '状態', '雰囲気', '言語/地域', '作者', '未分類'];
    // 32bit ARGB カラー値
    const colorValues = [
      0xFFFF9800, // コンテンツタイプ (orange)
      0xFF2196F3, // ジャンル (blue)
      0xFFFF5252, // 状態 (redAccent)
      0xFF009688, // 雰囲気 (teal)
      0xFF00BCD4, // 言語/地域 (cyan)
      0xFF9C27B0, // 作者 (purple)
      0xFF9E9E9E, // 未分類 (grey)
    ];
    await _isar.writeTxn(() async {
      for (var i = 0; i < names.length; i++) {
        final name = names[i];
        final colorValue = colorValues[i];
        final existing = await _isar.tagFacets
            .filter()
            .nameEqualTo(name)
            .findFirst();
        if (existing == null) {
          final facet = TagFacet()
            ..name = name
            ..colorValue = colorValue
            ..sortOrder = i
            ..createdAt = DateTime.now();
          await _isar.tagFacets.put(facet);
        } else {
          // デフォルトFacetの色や順序を更新
          if (existing.colorValue != colorValue || existing.sortOrder != i) {
            existing.colorValue = colorValue;
            existing.sortOrder = i;
            await _isar.tagFacets.put(existing);
          }
        }
      }
    });
  }

  Future<TagFacet> _ensureFacet(String name) async {
    final existing = await _isar.tagFacets
        .filter()
        .nameEqualTo(name)
        .findFirst();
    if (existing != null) return existing;

    final facet = TagFacet()
      ..name = name
      ..createdAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.tagFacets.put(facet);
    });
    return facet;
  }
}

class _TagPreset {
  final String name;
  final int? facetId;
  final int? colorValue;
  final String? legacyName;
  _TagPreset(this.name, this.facetId, this.colorValue, {this.legacyName});
}

enum TagPresetConflictPolicy { keepExisting, overwrite }

class TagPresetImportResult {
  final int createdFacetCount;
  final int updatedFacetCount;
  final int skippedFacetCount;
  final int createdTagCount;
  final int updatedTagCount;
  final int skippedTagCount;

  int get facetCount => createdFacetCount + updatedFacetCount;
  int get tagCount => createdTagCount + updatedTagCount;
  int get createdCount => createdFacetCount + createdTagCount;
  int get updatedCount => updatedFacetCount + updatedTagCount;
  int get skippedCount => skippedFacetCount + skippedTagCount;

  const TagPresetImportResult({
    required this.createdFacetCount,
    required this.updatedFacetCount,
    required this.skippedFacetCount,
    required this.createdTagCount,
    required this.updatedTagCount,
    required this.skippedTagCount,
  });
}

class TagPresetExportData {
  final String jsonString;
  final String fileName;
  final int facetCount;
  final int tagCount;

  const TagPresetExportData({
    required this.jsonString,
    required this.fileName,
    required this.facetCount,
    required this.tagCount,
  });
}

class TagPresetExportResult {
  final String path;
  final int facetCount;
  final int tagCount;

  const TagPresetExportResult({
    required this.path,
    required this.facetCount,
    required this.tagCount,
  });
}

class TagPresetImportPreview {
  final int createFacetCount;
  final int updateFacetCount;
  final int skipFacetCount;
  final int createTagCount;
  final int updateTagCount;
  final int skipTagCount;
  const TagPresetImportPreview({
    required this.createFacetCount,
    required this.updateFacetCount,
    required this.skipFacetCount,
    required this.createTagCount,
    required this.updateTagCount,
    required this.skipTagCount,
  });
}

enum TagPresetValidationCode { emptyFacetName, missingFacetHeader }

class TagPresetValidationIssue {
  final int line;
  final TagPresetValidationCode code;
  const TagPresetValidationIssue({required this.line, required this.code});
}

class TagPresetImportData {
  final List<TagPresetFacetData> facets;
  final List<TagPresetTagData> tags;
  final bool requireSelfContainedParents;
  const TagPresetImportData({
    required this.facets,
    required this.tags,
    this.requireSelfContainedParents = false,
  });
}

class TagPresetFacetData {
  final String name;
  final int? colorValue;
  final int? sortOrder;
  final DateTime? createdAt;
  final bool hasColorValue;
  final bool hasSortOrder;
  const TagPresetFacetData(
    this.name, {
    this.colorValue,
    this.sortOrder,
    this.createdAt,
    this.hasColorValue = false,
    this.hasSortOrder = false,
  });

  @override
  bool operator ==(Object other) {
    return other is TagPresetFacetData && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}

class TagPresetTagData {
  final String name;
  final String? facetName;
  final String? parentName;
  final String? parentFacetName;
  final int? level;
  final int? colorValue;
  final DateTime? createdAt;
  final bool? isHidden;
  final bool hasParentName;
  final bool hasLevel;
  final bool hasColorValue;
  final bool hasIsHidden;
  const TagPresetTagData(
    this.name, {
    this.facetName,
    this.parentName,
    this.parentFacetName,
    this.level,
    this.colorValue,
    this.createdAt,
    this.isHidden,
    this.hasParentName = false,
    this.hasLevel = false,
    this.hasColorValue = false,
    this.hasIsHidden = false,
  });
}

class _TagPresetFileIo {
  const _TagPresetFileIo();

  Future<String?> pickPresetFileContent() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (result == null) return null;
    final length = await result.length();
    if (length != null && length > ImportSafetyPolicy.maxMetadataBytes) {
      throw AppError.validation('Tag preset file is too large');
    }
    final bytes = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in result.readAsByteStream()) {
      total += chunk.length;
      if (total > ImportSafetyPolicy.maxMetadataBytes) {
        throw AppError.validation('Tag preset file is too large');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }

  Future<String?> savePresetFile({
    required Uint8List bytes,
    required String fileName,
    String? dialogTitle,
  }) async {
    final uri = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
    );
    if (uri == null) return null;
    // file_picker 13 writes the bytes on every platform before returning.
    return uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
  }
}

class _TagPresetParser {
  const _TagPresetParser();

  void _validateTextSize(String text) {
    if (text.length > ImportSafetyPolicy.maxMetadataBytes ~/ 4) {
      throw AppError.validation('Tag preset input is too large');
    }
    if (utf8.encode(text).length > ImportSafetyPolicy.maxMetadataBytes) {
      throw AppError.validation('Tag preset input is too large');
    }
    var lineCount = 1;
    const maxLines = ImportSafetyPolicy.maxMetadataRecordsPerType * 2;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0A && ++lineCount > maxLines) {
        throw AppError.validation('Too many tag preset lines');
      }
    }
  }

  void validateData(TagPresetImportData data) {
    if (data.facets.length > ImportSafetyPolicy.maxMetadataRecordsPerType ||
        data.tags.length > ImportSafetyPolicy.maxMetadataRecordsPerType) {
      throw AppError.validation('Too many tag preset records');
    }
    final facetNames = <String>{};
    for (final facet in data.facets) {
      if (facet.name.isEmpty ||
          facet.name.length > 512 ||
          !facetNames.add(facet.name) ||
          (facet.colorValue != null &&
              (facet.colorValue! < 0 || facet.colorValue! > 0xFFFFFFFF))) {
        throw AppError.validation('Invalid facet name');
      }
    }

    final tagKeys = <({String facetName, String tagName})>{};
    for (final tag in data.tags) {
      final facetName = tag.facetName ?? '未分類';
      if (tag.name.isEmpty ||
          tag.name.length > 512 ||
          (tag.facetName?.length ?? 0) > 512 ||
          (tag.parentName?.length ?? 0) > 512 ||
          (tag.parentFacetName?.length ?? 0) > 512 ||
          (tag.level != null && (tag.level! <= 0 || tag.level! > 1000000)) ||
          (tag.colorValue != null &&
              (tag.colorValue! < 0 || tag.colorValue! > 0xFFFFFFFF)) ||
          !tagKeys.add((facetName: facetName, tagName: tag.name))) {
        throw AppError.validation('Invalid tag preset record');
      }
      final parentFacetName = tag.parentFacetName ?? facetName;
      if (tag.parentName != null && parentFacetName != facetName) {
        throw AppError.validation('Parent charm must use the same category');
      }
    }

    final parentByKey =
        <
          ({String facetName, String tagName}),
          ({String facetName, String tagName})?
        >{};
    for (final tag in data.tags) {
      final facetName = tag.facetName ?? '未分類';
      final key = (facetName: facetName, tagName: tag.name);
      final parentName = tag.parentName;
      if (parentName == null || parentName.isEmpty) {
        parentByKey[key] = null;
        continue;
      }
      final parentKey = (
        facetName: tag.parentFacetName ?? facetName,
        tagName: parentName,
      );
      if (data.requireSelfContainedParents && !tagKeys.contains(parentKey)) {
        throw AppError.validation(
          'Parent charm "$parentName" is missing from the file',
        );
      }
      if (tagKeys.contains(parentKey)) {
        parentByKey[key] = parentKey;
      }
    }

    for (final start in parentByKey.keys) {
      final visited = <({String facetName, String tagName})>{};
      var current = start;
      var depth = 0;
      while (true) {
        if (!visited.add(current)) {
          throw AppError.validation('Circular charm hierarchy detected');
        }
        final parent = parentByKey[current];
        if (parent == null) break;
        depth++;
        if (depth > ImportSafetyPolicy.maxRelativePathDepth) {
          throw AppError.validation('Charm hierarchy is too deep');
        }
        current = parent;
      }
    }
  }

  TagPresetImportData decodeJsonString(String jsonString) {
    _validateTextSize(jsonString);
    final decoded = jsonDecode(jsonString);
    TagPresetImportData data;
    if (decoded is Map<String, dynamic>) {
      final isCanonical =
          decoded.containsKey('format') || decoded.containsKey('version');
      if (isCanonical) {
        if (decoded['format'] != TagPresetService.exchangeFormat ||
            decoded['version'] != TagPresetService.exchangeVersion) {
          throw AppError.validation('Unsupported charm file format or version');
        }
      }
      data = _fromMap(decoded, strict: isCanonical);
    } else if (decoded is List) {
      data = _fromMap({'tags': decoded}, strict: false);
    } else {
      throw AppError.validation('Unsupported JSON format');
    }
    validateData(data);
    return data;
  }

  TagPresetImportData parseSimplifiedText(String text) {
    _validateTextSize(text);
    final lines = text.split('\n');
    final facets = <TagPresetFacetData>[];
    final tags = <TagPresetTagData>[];
    String? currentFacet;
    final parentStack = <({int indent, String name})>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        currentFacet = trimmed.substring(1, trimmed.length - 1).trim();
        if (currentFacet.isEmpty) continue;
        if (currentFacet.length > 512 ||
            facets.length >= ImportSafetyPolicy.maxMetadataRecordsPerType) {
          throw AppError.validation('Invalid or excessive tag facets');
        }
        if (!facets.any((facet) => facet.name == currentFacet)) {
          facets.add(TagPresetFacetData(currentFacet));
        }
        parentStack.clear();
        continue;
      }

      final indent = line.length - line.trimLeft().length;
      final tagName = trimmed;
      if (tagName.length > 512) {
        throw AppError.validation('Tag name is too long');
      }

      if (currentFacet == null) {
        currentFacet = '未分類';
        if (facets.length >= ImportSafetyPolicy.maxMetadataRecordsPerType) {
          throw AppError.validation('Too many tag facets');
        }
        facets.add(TagPresetFacetData(currentFacet));
      }

      while (parentStack.isNotEmpty && parentStack.last.indent >= indent) {
        parentStack.removeLast();
      }

      final parentName = parentStack.isNotEmpty ? parentStack.last.name : null;
      tags.add(
        TagPresetTagData(
          tagName,
          facetName: currentFacet,
          parentName: parentName,
          hasParentName: true,
        ),
      );
      if (tags.length > ImportSafetyPolicy.maxMetadataRecordsPerType ||
          parentStack.length >= ImportSafetyPolicy.maxRelativePathDepth) {
        throw AppError.validation('Tag preset hierarchy is too large or deep');
      }
      parentStack.add((indent: indent, name: tagName));
    }

    final data = TagPresetImportData(
      facets: facets,
      tags: tags,
      requireSelfContainedParents: true,
    );
    validateData(data);
    return data;
  }

  List<TagPresetValidationIssue> validateSimplifiedText(String text) {
    _validateTextSize(text);
    final lines = text.split('\n');
    final errors = <TagPresetValidationIssue>[];
    String? currentFacet;
    final parentStack = <int>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        currentFacet = trimmed.substring(1, trimmed.length - 1).trim();
        if (currentFacet.isEmpty) {
          errors.add(
            TagPresetValidationIssue(
              line: i + 1,
              code: TagPresetValidationCode.emptyFacetName,
            ),
          );
        }
        parentStack.clear();
        continue;
      }

      final indent = line.length - line.trimLeft().length;

      if (currentFacet == null) {
        errors.add(
          TagPresetValidationIssue(
            line: i + 1,
            code: TagPresetValidationCode.missingFacetHeader,
          ),
        );
        currentFacet = 'temp';
      }

      while (parentStack.isNotEmpty && parentStack.last >= indent) {
        parentStack.removeLast();
      }

      parentStack.add(indent);
    }
    return errors;
  }

  TagPresetImportData _fromMap(
    Map<String, dynamic> data, {
    required bool strict,
  }) {
    final rawFacets =
        data['categories'] ??
        data['facets'] ??
        data['tagFacets'] ??
        data['presetFacets'];
    final rawTags =
        data['charms'] ??
        data['tags'] ??
        data['tagPresets'] ??
        data['presetTags'] ??
        data['tagList'];
    if (strict && (rawFacets is! List || rawTags is! List)) {
      throw AppError.validation(
        'Charm file must contain categories and charms',
      );
    }
    if (rawFacets is List &&
        rawFacets.length > ImportSafetyPolicy.maxMetadataRecordsPerType) {
      throw AppError.validation('Too many tag facets');
    }
    if (rawTags is List &&
        rawTags.length > ImportSafetyPolicy.maxMetadataRecordsPerType) {
      throw AppError.validation('Too many tags');
    }
    return TagPresetImportData(
      facets: _parseFacetData(rawFacets, strict: strict),
      tags: _parseTagData(rawTags, strict: strict),
      requireSelfContainedParents: strict,
    );
  }

  List<TagPresetFacetData> _parseFacetData(
    dynamic raw, {
    required bool strict,
  }) {
    if (raw is! List) {
      return [];
    }
    return raw
        .map<TagPresetFacetData?>((entry) {
          if (entry is String) {
            if (strict) {
              throw AppError.validation('Invalid charm category record');
            }
            final name = entry.trim();
            return name.isEmpty ? null : TagPresetFacetData(name);
          }
          if (entry is Map<String, dynamic>) {
            final name = (entry['name'] as String?)?.trim();
            if (name == null || name.isEmpty) {
              if (strict) {
                throw AppError.validation('Invalid charm category record');
              }
              return null;
            }
            final hasColor =
                entry.containsKey('colorValue') || entry.containsKey('color');
            final rawColor = entry['colorValue'] ?? entry['color'];
            final colorValue = _parseColorValue(rawColor);
            final hasSortOrder = entry.containsKey('sortOrder');
            final sortOrder = _parseInt(entry['sortOrder']);
            if (strict &&
                ((hasColor && rawColor != null && colorValue == null) ||
                    (hasSortOrder && sortOrder == null))) {
              throw AppError.validation('Invalid charm category record');
            }
            return TagPresetFacetData(
              name,
              colorValue: colorValue,
              sortOrder: sortOrder,
              createdAt: _parseDate(entry['createdAt']),
              hasColorValue: hasColor,
              hasSortOrder: hasSortOrder,
            );
          }
          if (strict) {
            throw AppError.validation('Invalid charm category record');
          }
          return null;
        })
        .whereType<TagPresetFacetData>()
        .toList();
  }

  List<TagPresetTagData> _parseTagData(dynamic raw, {required bool strict}) {
    if (raw is! List) {
      return [];
    }
    return raw
        .map<TagPresetTagData?>((entry) {
          if (entry is String) {
            if (strict) {
              throw AppError.validation('Invalid charm record');
            }
            final name = entry.trim();
            return name.isEmpty ? null : TagPresetTagData(name);
          }
          if (entry is Map<String, dynamic>) {
            final name = (entry['name'] as String?)?.trim();
            if (name == null || name.isEmpty) {
              if (strict) {
                throw AppError.validation('Invalid charm record');
              }
              return null;
            }
            final facetName =
                (entry['category'] ??
                        entry['facet'] ??
                        entry['facetName'] ??
                        entry['facet_name'])
                    ?.toString()
                    .trim();
            final parentName = (entry['parent'] ?? entry['parentName'])
                ?.toString()
                .trim();
            final parentFacetName =
                (entry['parentFacet'] ?? entry['parentFacetName'])
                    ?.toString()
                    .trim();
            final hasParent =
                entry.containsKey('parent') || entry.containsKey('parentName');
            final hasLevel = entry.containsKey('level');
            final level = _parseInt(entry['level']);
            final hasColor =
                entry.containsKey('colorValue') || entry.containsKey('color');
            final rawColor = entry['colorValue'] ?? entry['color'];
            final colorValue = _parseColorValue(rawColor);
            final hasHidden =
                entry.containsKey('hidden') || entry.containsKey('isHidden');
            final rawHidden = entry['hidden'] ?? entry['isHidden'];
            final isHidden = _parseBool(rawHidden);
            if (strict &&
                ((facetName?.isEmpty ?? true) ||
                    !hasParent ||
                    (hasLevel && level == null) ||
                    (hasColor && rawColor != null && colorValue == null) ||
                    (hasHidden && isHidden == null))) {
              throw AppError.validation('Invalid charm record');
            }
            return TagPresetTagData(
              name,
              facetName: (facetName?.isEmpty ?? true) ? null : facetName,
              parentName: (parentName?.isEmpty ?? true) ? null : parentName,
              parentFacetName: (parentFacetName?.isEmpty ?? true)
                  ? null
                  : parentFacetName,
              level: level,
              colorValue: colorValue,
              createdAt: _parseDate(entry['createdAt']),
              isHidden: isHidden,
              hasParentName: hasParent,
              hasLevel: hasLevel,
              hasColorValue: hasColor,
              hasIsHidden: hasHidden,
            );
          }
          if (strict) {
            throw AppError.validation('Invalid charm record');
          }
          return null;
        })
        .whereType<TagPresetTagData>()
        .toList();
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  bool? _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  int? _parseColorValue(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      var raw = value.trim();
      if (raw.isEmpty) return null;
      if (raw.startsWith('0x') || raw.startsWith('0X')) {
        return int.tryParse(raw.substring(2), radix: 16);
      }
      if (raw.startsWith('#')) {
        raw = raw.substring(1);
      }
      raw = raw.toUpperCase();
      if (raw.length == 6) {
        raw = 'FF$raw';
      }
      return int.tryParse(raw, radix: 16);
    }
    return null;
  }
}

typedef _LogicalTagKey = ({String facetName, String tagName});

enum _ImportAction { create, update, skip }

class _TagImportPlan {
  final List<TagPresetFacetData> facetInputs;
  final Map<String, _ImportAction> facetActions;
  final Map<_LogicalTagKey, _ImportAction> tagActions;
  final TagPresetImportPreview preview;

  const _TagImportPlan({
    required this.facetInputs,
    required this.facetActions,
    required this.tagActions,
    required this.preview,
  });
}

class _TagHierarchy {
  final int level;
  final List<int> ancestorIds;

  const _TagHierarchy({required this.level, required this.ancestorIds});
}

class _TagPresetPersistence {
  final Isar _isar;
  const _TagPresetPersistence(this._isar);

  Future<TagPresetImportResult> importData(
    TagPresetImportData data, {
    required TagPresetConflictPolicy conflictPolicy,
  }) async {
    final plan = await _prepare(data, conflictPolicy: conflictPolicy);

    await _isar.writeTxn(() async {
      final existingFacets = await _isar.tagFacets.where().findAll();
      final facetByName = <String, TagFacet>{
        for (final facet in existingFacets) facet.name: facet,
      };
      var nextSortOrder = existingFacets.isEmpty
          ? 0
          : existingFacets
                    .map((facet) => facet.sortOrder)
                    .reduce((a, b) => a > b ? a : b) +
                1;

      for (final input in plan.facetInputs) {
        final action = plan.facetActions[input.name]!;
        final existing = facetByName[input.name];
        if (action == _ImportAction.create) {
          final facet = TagFacet()
            ..name = input.name
            ..colorValue = input.colorValue
            ..sortOrder = input.sortOrder ?? nextSortOrder++
            ..createdAt = input.createdAt ?? DateTime.now();
          await _isar.tagFacets.put(facet);
          facetByName[input.name] = facet;
        } else if (action == _ImportAction.update && existing != null) {
          if (input.hasColorValue) existing.colorValue = input.colorValue;
          if (input.hasSortOrder && input.sortOrder != null) {
            existing.sortOrder = input.sortOrder!;
          }
          await _isar.tagFacets.put(existing);
        }
      }

      final tagsBefore = await _isar.tags.where().findAll();
      final tagByLogicalKey = _tagsByLogicalKey(tagsBefore, facetByName);
      final affectedIds = <int>{};

      for (final input in data.tags) {
        final logicalKey = _inputKey(input);
        final action = plan.tagActions[logicalKey]!;
        if (action == _ImportAction.skip) continue;

        final facet = facetByName[logicalKey.facetName];
        if (facet == null) {
          throw AppError.validation(
            'Category "${logicalKey.facetName}" could not be created',
          );
        }
        var tag = tagByLogicalKey[logicalKey];
        if (action == _ImportAction.create) {
          tag = Tag()
            ..key = Tag.buildKey(facet.id, input.name)
            ..name = input.name
            ..facetId = facet.id
            ..parentId = null
            ..level = input.level ?? 100
            ..ancestorIds = []
            ..colorValue = input.colorValue
            ..isHidden = input.isHidden ?? false
            ..createdAt = input.createdAt ?? DateTime.now();
        } else if (tag != null) {
          if (input.hasLevel && input.level != null) tag.level = input.level!;
          if (input.hasColorValue) tag.colorValue = input.colorValue;
          if (input.hasIsHidden && input.isHidden != null) {
            tag.isHidden = input.isHidden!;
          }
        }
        if (tag == null) {
          throw AppError.validation('Charm "${input.name}" was not found');
        }
        await _isar.tags.put(tag);
        tagByLogicalKey[logicalKey] = tag;
        affectedIds.add(tag.id);
      }

      var allTags = await _isar.tags.where().findAll();
      final allTagsByLogicalKey = _tagsByLogicalKey(allTags, facetByName);
      for (final input in data.tags) {
        final logicalKey = _inputKey(input);
        final action = plan.tagActions[logicalKey]!;
        if (action == _ImportAction.skip || !input.hasParentName) continue;

        final tag = allTagsByLogicalKey[logicalKey]!;
        final parentName = input.parentName;
        Tag? parent;
        if (parentName != null && parentName.isNotEmpty) {
          final parentKey = (
            facetName: input.parentFacetName ?? logicalKey.facetName,
            tagName: parentName,
          );
          parent = allTagsByLogicalKey[parentKey];
          if (parent == null) {
            throw AppError.validation(
              'Parent charm "$parentName" was not found',
            );
          }
        }
        if (tag.parentId != parent?.id) {
          tag.parentId = parent?.id;
          await _isar.tags.put(tag);
          affectedIds.add(tag.id);
        }
      }

      allTags = await _isar.tags.where().findAll();
      final tagById = {for (final tag in allTags) tag.id: tag};
      final childrenByParentId = <int, List<int>>{};
      for (final tag in allTags) {
        final parentId = tag.parentId;
        if (parentId != null) {
          childrenByParentId.putIfAbsent(parentId, () => []).add(tag.id);
        }
      }
      final pendingIds = [...affectedIds];
      for (var index = 0; index < pendingIds.length; index++) {
        final children = childrenByParentId[pendingIds[index]] ?? const <int>[];
        for (final childId in children) {
          if (affectedIds.add(childId)) pendingIds.add(childId);
        }
      }

      final hierarchyById = <int, _TagHierarchy>{};
      _TagHierarchy resolveHierarchy(int id, Set<int> visiting) {
        final cached = hierarchyById[id];
        if (cached != null) return cached;
        if (!visiting.add(id)) {
          throw AppError.validation('Circular charm hierarchy detected');
        }
        final tag = tagById[id];
        if (tag == null) {
          throw AppError.validation('Charm hierarchy is incomplete');
        }
        final parentId = tag.parentId;
        late final _TagHierarchy hierarchy;
        if (parentId == null) {
          hierarchy = _TagHierarchy(
            level: tag.level > 0 ? tag.level : 100,
            ancestorIds: const [],
          );
        } else {
          final parent = tagById[parentId];
          if (parent == null || parent.facetId != tag.facetId) {
            throw AppError.validation('Charm hierarchy is incomplete');
          }
          final parentHierarchy = resolveHierarchy(parentId, visiting);
          if (parentHierarchy.ancestorIds.length + 1 >
              ImportSafetyPolicy.maxRelativePathDepth) {
            throw AppError.validation('Charm hierarchy is too deep');
          }
          hierarchy = _TagHierarchy(
            level: parentHierarchy.level + 1,
            ancestorIds: [parentId, ...parentHierarchy.ancestorIds],
          );
        }
        visiting.remove(id);
        hierarchyById[id] = hierarchy;
        return hierarchy;
      }

      for (final id in affectedIds) {
        final tag = tagById[id]!;
        final hierarchy = resolveHierarchy(id, <int>{});
        final ancestorsChanged =
            tag.ancestorIds.length != hierarchy.ancestorIds.length ||
            !_sameInts(tag.ancestorIds, hierarchy.ancestorIds);
        if (tag.level != hierarchy.level || ancestorsChanged) {
          tag
            ..level = hierarchy.level
            ..ancestorIds = hierarchy.ancestorIds;
          await _isar.tags.put(tag);
        }
      }
    });

    final preview = plan.preview;
    return TagPresetImportResult(
      createdFacetCount: preview.createFacetCount,
      updatedFacetCount: preview.updateFacetCount,
      skippedFacetCount: preview.skipFacetCount,
      createdTagCount: preview.createTagCount,
      updatedTagCount: preview.updateTagCount,
      skippedTagCount: preview.skipTagCount,
    );
  }

  Future<TagPresetImportPreview> buildPreview(
    TagPresetImportData data, {
    required TagPresetConflictPolicy conflictPolicy,
  }) async {
    return (await _prepare(data, conflictPolicy: conflictPolicy)).preview;
  }

  Future<_TagImportPlan> _prepare(
    TagPresetImportData data, {
    required TagPresetConflictPolicy conflictPolicy,
  }) async {
    final facetInputByName = <String, TagPresetFacetData>{
      for (final facet in data.facets) facet.name: facet,
    };
    for (final tag in data.tags) {
      final facetName = tag.facetName ?? '未分類';
      facetInputByName.putIfAbsent(
        facetName,
        () => TagPresetFacetData(facetName),
      );
    }
    final facetInputs = facetInputByName.values.toList();

    final existingFacets = await _isar.tagFacets.where().findAll();
    final existingFacetByName = <String, TagFacet>{
      for (final facet in existingFacets) facet.name: facet,
    };
    final facetActions = <String, _ImportAction>{};
    var createFacetCount = 0;
    var updateFacetCount = 0;
    var skipFacetCount = 0;
    for (final input in facetInputs) {
      final existing = existingFacetByName[input.name];
      if (existing == null) {
        facetActions[input.name] = _ImportAction.create;
        createFacetCount++;
        continue;
      }
      final shouldUpdate =
          conflictPolicy == TagPresetConflictPolicy.overwrite &&
          ((input.hasColorValue && existing.colorValue != input.colorValue) ||
              (input.hasSortOrder &&
                  input.sortOrder != null &&
                  existing.sortOrder != input.sortOrder));
      if (shouldUpdate) {
        facetActions[input.name] = _ImportAction.update;
        updateFacetCount++;
      } else {
        facetActions[input.name] = _ImportAction.skip;
        skipFacetCount++;
      }
    }

    final existingTags = await _isar.tags.where().findAll();
    final existingTagByKey = _tagsByLogicalKey(
      existingTags,
      existingFacetByName,
    );
    final existingTagById = {for (final tag in existingTags) tag.id: tag};
    final currentParentByKey = <_LogicalTagKey, _LogicalTagKey?>{};
    for (final entry in existingTagByKey.entries) {
      final parent = entry.value.parentId == null
          ? null
          : existingTagById[entry.value.parentId!];
      currentParentByKey[entry.key] = parent == null
          ? null
          : _logicalKeyForTag(parent, existingFacetByName);
    }

    final inputByKey = <_LogicalTagKey, TagPresetTagData>{
      for (final input in data.tags) _inputKey(input): input,
    };
    final allKeys = <_LogicalTagKey>{
      ...existingTagByKey.keys,
      ...inputByKey.keys,
    };
    final effectiveParentByKey = Map<_LogicalTagKey, _LogicalTagKey?>.from(
      currentParentByKey,
    );

    final tagActions = <_LogicalTagKey, _ImportAction>{};
    var createTagCount = 0;
    var updateTagCount = 0;
    var skipTagCount = 0;
    for (final entry in inputByKey.entries) {
      final key = entry.key;
      final input = entry.value;
      final existing = existingTagByKey[key];
      final desiredParent = _parentKey(input);
      if (existing == null) {
        tagActions[key] = _ImportAction.create;
        effectiveParentByKey[key] = input.hasParentName ? desiredParent : null;
        createTagCount++;
        continue;
      }

      final shouldUpdate =
          conflictPolicy == TagPresetConflictPolicy.overwrite &&
          ((input.hasLevel &&
                  input.level != null &&
                  existing.level != input.level) ||
              (input.hasColorValue &&
                  existing.colorValue != input.colorValue) ||
              (input.hasIsHidden &&
                  input.isHidden != null &&
                  existing.isHidden != input.isHidden) ||
              (input.hasParentName &&
                  currentParentByKey[key] != desiredParent));
      if (shouldUpdate) {
        tagActions[key] = _ImportAction.update;
        if (input.hasParentName) effectiveParentByKey[key] = desiredParent;
        updateTagCount++;
      } else {
        tagActions[key] = _ImportAction.skip;
        skipTagCount++;
      }
    }

    for (final start in inputByKey.keys) {
      final visited = <_LogicalTagKey>{};
      var current = start;
      var depth = 0;
      while (true) {
        if (!visited.add(current)) {
          throw AppError.validation('Circular charm hierarchy detected');
        }
        final parent = effectiveParentByKey[current];
        if (parent == null) break;
        if (parent.facetName != current.facetName) {
          throw AppError.validation('Parent charm must use the same category');
        }
        if (!allKeys.contains(parent)) {
          throw AppError.validation(
            'Parent charm "${parent.tagName}" was not found',
          );
        }
        depth++;
        if (depth > ImportSafetyPolicy.maxRelativePathDepth) {
          throw AppError.validation('Charm hierarchy is too deep');
        }
        current = parent;
      }
    }

    return _TagImportPlan(
      facetInputs: facetInputs,
      facetActions: facetActions,
      tagActions: tagActions,
      preview: TagPresetImportPreview(
        createFacetCount: createFacetCount,
        updateFacetCount: updateFacetCount,
        skipFacetCount: skipFacetCount,
        createTagCount: createTagCount,
        updateTagCount: updateTagCount,
        skipTagCount: skipTagCount,
      ),
    );
  }

  static Map<_LogicalTagKey, Tag> _tagsByLogicalKey(
    List<Tag> tags,
    Map<String, TagFacet> facetByName,
  ) {
    final facetNameById = {
      for (final facet in facetByName.values) facet.id: facet.name,
    };
    final result = <_LogicalTagKey, Tag>{};
    for (final tag in tags) {
      final facetName = tag.facetId == null
          ? null
          : facetNameById[tag.facetId!];
      if (facetName != null) {
        result[(facetName: facetName, tagName: tag.name)] = tag;
      }
    }
    return result;
  }

  static _LogicalTagKey? _logicalKeyForTag(
    Tag tag,
    Map<String, TagFacet> facetByName,
  ) {
    final facetId = tag.facetId;
    if (facetId == null) return null;
    for (final facet in facetByName.values) {
      if (facet.id == facetId) {
        return (facetName: facet.name, tagName: tag.name);
      }
    }
    return null;
  }

  static _LogicalTagKey _inputKey(TagPresetTagData input) =>
      (facetName: input.facetName ?? '未分類', tagName: input.name);

  static _LogicalTagKey? _parentKey(TagPresetTagData input) {
    final parentName = input.parentName;
    if (parentName == null || parentName.isEmpty) return null;
    final facetName = input.facetName ?? '未分類';
    return (facetName: input.parentFacetName ?? facetName, tagName: parentName);
  }

  static bool _sameInts(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
