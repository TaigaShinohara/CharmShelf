// 撮影専用の見本データ。アプリのビルド・起動経路には含めない。
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/storage_ref.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';

Future<void> main() async {
  final root = Directory('build/store-screenshot-fixture');
  if (root.existsSync()) {
    throw StateError('既存の撮影データは上書きしません: ${root.path}');
  }
  await root.create(recursive: true);
  final isar = await Isar.open(
    [
      MediaItemSchema,
      TagSchema,
      TagFacetSchema,
      MediaCollectionSchema,
      StorageRefSchema,
    ],
    directory: root.absolute.path,
    inspector: false,
  );
  final date = DateTime(2026, 8, 31, 9, 41);
  final facet = TagFacet()
    ..name = 'テーマ'
    ..createdAt = date;
  final samples = <(String, String, int, List<(String, String)>)>[
    (
      '旅のしおり',
      '旅行',
      0xff3d78b8,
      [
        (
          '週末の持ちもの.md',
          '# 週末の持ちもの\n\n## 小さな旅の準備\n\n- ノートとペン\n- 水筒\n- 歩きやすい靴\n- 充電器\n\n## 旅のメモ\n\n気になった風景や、また訪れたい場所をまとめておく。\n\n> この文書は掲載画像用の見本です。\n',
        ),
        ('散歩の計画.md', '# 散歩の計画\n\n午前は川沿いを歩く。午後は本屋に立ち寄る。\n\n撮影用の架空のメモです。\n'),
        ('訪れたい場所.md', '# 訪れたい場所\n\n- 静かな公園\n- 小さな図書館\n- 海の見える道\n'),
      ],
    ),
    (
      '読書ノート',
      '読書',
      0xff7b65a5,
      [
        (
          '読みながら考えたこと.md',
          '# 読みながら考えたこと\n\n## ノートの使い方\n\n気になったことを自分の言葉で残す。\n\nこれは架空の見本文書です。書籍からの引用は含みません。\n',
        ),
        ('次に読む本のメモ.md', '# 次に読む本のメモ\n\n気になるテーマを集めて、自分だけの読書リストに。\n'),
      ],
    ),
    (
      '仕事の資料',
      '仕事',
      0xff448b7e,
      [
        (
          '制作チェックリスト.md',
          '# 制作チェックリスト\n\n- 目的を決める\n- 素材を整理する\n- 内容を見直す\n\n掲載画像用の架空の資料です。\n',
        ),
        ('アイデアの整理.md', '# アイデアの整理\n\n## 今週のテーマ\n\n探しやすく、見返しやすく。\n'),
      ],
    ),
    (
      'アイデア帳',
      'ひらめき',
      0xffb8874d,
      [
        ('小さなひらめき.md', '# 小さなひらめき\n\n日々思いついたことを、一つずつ書きとめる。\n\n撮影用の見本データです。\n'),
        ('やってみたいこと.md', '# やってみたいこと\n\n- 朝に少し歩く\n- 新しい料理を作る\n- ノートを整理する\n'),
      ],
    ),
  ];
  await isar.writeTxn(() async {
    await isar.tagFacets.put(facet);
    for (var i = 0; i < samples.length; i++) {
      final (title, tagName, color, documents) = samples[i];
      final folder = 'library/$title';
      await Directory('${root.path}/$folder').create(recursive: true);
      final tag = Tag()
        ..name = tagName
        ..key = Tag.buildKey(facet.id, tagName)
        ..facetId = facet.id
        ..colorValue = color
        ..createdAt = date
        ..usageCount = 1;
      await isar.tags.put(tag);
      final items = <MediaItem>[
        MediaItem()
          ..uid = 'store-folder-$i'
          ..path = folder
          ..type = MediaType.folder
          ..addedAt = date.subtract(Duration(minutes: i))
          ..updatedAt = date,
      ];
      for (var j = 0; j < documents.length; j++) {
        final (name, content) = documents[j];
        final file = File('${root.path}/$folder/$name');
        await file.writeAsString(content);
        items.add(
          MediaItem()
            ..uid = 'store-document-$i-$j'
            ..path = '$folder/$name'
            ..parentPath = folder
            ..size = await file.length()
            ..addedAt = date
            ..updatedAt = date,
        );
      }
      await isar.mediaItems.putAll(items);
      final collection = MediaCollection()
        ..uid = 'store-catalog-$i'
        ..title = title
        ..path = folder
        ..isCatalog = true
        ..createdAt = date.subtract(Duration(minutes: i))
        ..updatedAt = date
        ..isPinned = true
        ..isFavorite = i < 2
        ..notes = '掲載画像用の見本データ'
        ..items.addAll(items)
        ..tags.add(tag);
      await isar.mediaCollections.put(collection);
      await collection.items.save();
      await collection.tags.save();
    }
  });
  await isar.close();
  stdout.writeln('撮影用データを作成: ${root.path}');
}
