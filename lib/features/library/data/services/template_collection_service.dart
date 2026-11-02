import 'dart:io';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

class TemplateCollectionService {
  final Isar _isar;
  final FileService _fileService;
  final _uuid = const Uuid();

  TemplateCollectionService(this._isar, this._fileService);

  /// 初回起動用のウェルカムコンテンツを作成する
  Future<Result<void, AppError>> createWelcomeCollection() async {
    try {
      AppLogger.i(LogTag.storage, 'ウェルカムコンテンツの作成を開始');

      final now = DateTime.now();

      // 1. DocBook テンプレートの作成
      final docBookResult = await _createDocBookTemplate(now);
      if (docBookResult.isFailure) return docBookResult;

      // 2. 活用例のサンプルカタログを作成
      final sampleResult = await _createSampleCollections(now);
      if (sampleResult.isFailure) return sampleResult;

      // 3. ビデオテンプレートの作成
      final videoResult = await _createVideoTemplate(now);
      if (videoResult.isFailure) return videoResult;

      // 4. 音声テンプレートの作成
      final audioResult = await _createAudioTemplate(now);
      if (audioResult.isFailure) return audioResult;

      AppLogger.i(LogTag.storage, '全てのウェルカムコンテンツの作成が完了しました');
      return Result.success(null);
    } catch (e, st) {
      AppLogger.e(LogTag.storage, 'ウェルカムコンテンツの作成に失敗しました', e, st);
      return Result.failure(
        AppError.file('Failed to create welcome collection: $e'),
      );
    }
  }

  Future<Result<void, AppError>> _createSampleCollections(DateTime now) async {
    final isJa = (await _resolveLocaleCode()) == 'ja';

    final photoResult = await _createAssetFolderTemplate(
      now: now,
      dirName: isJa ? '春の旅｜フォトブック' : 'Spring Trip | Photo Book',
      title: isJa ? '春の旅｜フォトブック' : 'Spring Trip | Photo Book',
      alias: isJa ? '写真のサンプル' : 'Photo Book Example',
      notes: isJa
          ? '写真を1冊のフォトブックのようにまとめたサンプルです。'
          : 'A sample showing how photos can live together like a photo book.',
      isCatalog: true,
      tagRefs: [
        _TemplateTagRef(
          isJa ? '写真' : 'Photo',
          facetName: isJa ? 'コンテンツタイプ' : 'Content type',
        ),
        _TemplateTagRef(
          isJa ? '保存版' : 'Keep',
          facetName: isJa ? '状態' : 'Status',
        ),
      ],
      assets: [
        _TemplateAsset(
          assetPath: 'assets/images/samples/photo_book/spring_trip_coast.png',
          fileName: '01_coast.png',
          title: isJa ? '海辺の路地' : 'Coastal Lane',
        ),
        _TemplateAsset(
          assetPath: 'assets/images/samples/photo_book/spring_trip_evening.png',
          fileName: '02_evening.png',
          title: isJa ? '夕暮れの街' : 'Evening Town',
        ),
        _TemplateAsset(
          assetPath: 'assets/images/samples/photo_book/spring_trip_morning.png',
          fileName: '03_morning.png',
          title: isJa ? '朝の桟橋' : 'Morning Pier',
        ),
      ],
    );
    if (photoResult.isFailure) return photoResult;

    final musicResult = await _createAssetFolderTemplate(
      now: now,
      dirName: isJa ? '夜の作業用｜音楽アルバム' : 'Night Focus | Music Album',
      title: isJa ? '夜の作業用｜音楽アルバム' : 'Night Focus | Music Album',
      alias: isJa ? '音楽アルバムのサンプル' : 'Music Album Example',
      notes: isJa
          ? '音声ファイルをテーマごとのアルバムとしてまとめたサンプルです。'
          : 'A sample showing how audio can be organized as a themed album.',
      isCatalog: true,
      tagRefs: [
        _TemplateTagRef(
          isJa ? '音楽' : 'Music',
          facetName: isJa ? 'コンテンツタイプ' : 'Content type',
        ),
        _TemplateTagRef(
          isJa ? '保存版' : 'Keep',
          facetName: isJa ? '状態' : 'Status',
        ),
      ],
      assets: [
        _TemplateAsset(
          assetPath: 'assets/images/samples/music_album/night_focus_cover.png',
          fileName: 'cover.png',
          title: isJa ? 'アルバムカバー' : 'Album Cover',
        ),
        _TemplateAsset(
          assetPath: 'assets/sounds/digital_shelf_life.mp3',
          fileName: 'digital_shelf_life.mp3',
          title: isJa ? 'Digital Shelf Life' : 'Digital Shelf Life',
        ),
        const _TemplateAsset(
          assetPath: 'assets/sounds/suki_ga_totonou_tagshelf_pv.mp3',
          fileName: 'suki_ga_totonou_tagshelf_pv.mp3',
          title: '好きが整う — CharmShelf PV',
        ),
        _TemplateAsset(
          assetPath: isJa
              ? 'assets/text/samples/text_book/ja/tagshelf_usage.md'
              : 'assets/text/samples/text_book/en/tagshelf_usage.md',
          fileName: isJa ? 'アルバム紹介.md' : 'About This Album.md',
          title: isJa ? 'アルバム紹介' : 'About This Album',
        ),
      ],
    );
    if (musicResult.isFailure) return musicResult;

    final illustrationResult = await _createAssetFolderTemplate(
      now: now,
      dirName: isJa
          ? 'CharmShelf作品集｜イラスト'
          : 'CharmShelf Collection | Illustrations',
      title: isJa ? 'CharmShelf作品集｜イラスト' : 'CharmShelf Collection | Illustrations',
      alias: isJa ? 'イラスト集のサンプル' : 'Illustration Collection Example',
      notes: isJa
          ? '作品をシリーズごとのイラスト集としてまとめたサンプルです。'
          : 'A sample showing how works can live together as an art collection.',
      isCatalog: true,
      tagRefs: [
        _TemplateTagRef(
          isJa ? 'イラスト' : 'Illustration',
          facetName: isJa ? 'コンテンツタイプ' : 'Content type',
        ),
        _TemplateTagRef(
          isJa ? '保存版' : 'Keep',
          facetName: isJa ? '状態' : 'Status',
        ),
      ],
      assets: [
        _TemplateAsset(
          assetPath:
              'assets/images/samples/illustration_collection/moonlit_reader.png',
          fileName: '01_moonlit_reader.png',
          title: isJa ? '月明かりの読書家' : 'Moonlit Reader',
        ),
        _TemplateAsset(
          assetPath:
              'assets/images/samples/illustration_collection/botanical_atelier.png',
          fileName: '02_botanical_atelier.png',
          title: isJa ? '植物のアトリエ' : 'Botanical Atelier',
        ),
        _TemplateAsset(
          assetPath:
              'assets/images/samples/illustration_collection/starlight_observatory.png',
          fileName: '03_starlight_observatory.png',
          title: isJa ? '星明かりの観測室' : 'Starlight Observatory',
        ),
      ],
    );
    if (illustrationResult.isFailure) return illustrationResult;

    return _createAssetFolderTemplate(
      now: now,
      dirName: isJa ? 'あとで読む｜テキスト本' : 'Read Later | Text Book',
      title: isJa ? 'あとで読む｜テキスト本' : 'Read Later | Text Book',
      alias: isJa ? 'テキスト本のサンプル' : 'Text Book Example',
      notes: isJa
          ? 'メモや資料を、あとで読む本としてまとめたサンプルです。'
          : 'A sample showing how notes and references can become a book to read later.',
      isCatalog: true,
      tagRefs: [
        _TemplateTagRef(
          isJa ? '記事' : 'Article',
          facetName: isJa ? 'コンテンツタイプ' : 'Content type',
        ),
        _TemplateTagRef(
          isJa ? '積読' : 'Read later',
          facetName: isJa ? '状態' : 'Status',
        ),
        _TemplateTagRef(
          isJa ? '日本語' : 'English',
          facetName: isJa ? '言語/地域' : 'Language / Region',
        ),
      ],
      assets: [
        _TemplateAsset(
          assetPath: isJa
              ? 'assets/text/samples/text_book/ja/reading_notes.md'
              : 'assets/text/samples/text_book/en/reading_notes.md',
          fileName: isJa ? '読書メモ.md' : 'Reading Notes.md',
          title: isJa ? '読書メモ' : 'Reading Notes',
        ),
        _TemplateAsset(
          assetPath: isJa
              ? 'assets/text/samples/text_book/ja/recipe_collection.md'
              : 'assets/text/samples/text_book/en/recipe_collection.md',
          fileName: isJa ? 'レシピ集.md' : 'Recipe Collection.md',
          title: isJa ? 'レシピ集' : 'Recipe Collection',
        ),
        _TemplateAsset(
          assetPath: isJa
              ? 'assets/text/samples/text_book/ja/tagshelf_usage.md'
              : 'assets/text/samples/text_book/en/tagshelf_usage.md',
          fileName: isJa ? '活用メモ.md' : 'CharmShelf Usage Notes.md',
          title: isJa ? '活用メモ' : 'CharmShelf Usage Notes',
        ),
      ],
    );
  }

  Future<Result<void, AppError>> _createAssetFolderTemplate({
    required DateTime now,
    required String dirName,
    required String title,
    required String alias,
    required String notes,
    required bool isCatalog,
    required List<_TemplateTagRef> tagRefs,
    required List<_TemplateAsset> assets,
  }) async {
    try {
      final docsDir = await getPrivateStorageDirectory();
      final libraryDir = await _fileService.getLibraryDirectory();
      final dirPath = p.join(libraryDir.path, dirName);
      final relativeDirPath = p.relative(dirPath, from: docsDir.path);
      await Directory(dirPath).create(recursive: true);

      final items = <MediaItem>[
        _createItem(relativeDirPath, title, now, type: MediaType.folder),
      ];
      String? coverPath;

      for (var i = 0; i < assets.length; i++) {
        final asset = assets[i];
        final byteData = await rootBundle.load(asset.assetPath);
        final filePath = p.join(dirPath, asset.fileName);
        await File(filePath).writeAsBytes(byteData.buffer.asUint8List());
        final relativePath = p.relative(filePath, from: docsDir.path);
        if (i == 0) {
          coverPath = relativePath;
          items.first.thumbnailPath = relativePath;
        }
        items.add(
          _createItem(
            relativePath,
            asset.title,
            now,
            type: MediaType.file,
            parentPath: relativeDirPath,
          ),
        );
      }

      return await _registerCollection(
        title: title,
        alias: alias,
        notes: notes,
        dirName: dirName,
        isCatalog: isCatalog,
        type: CollectionType.folder,
        items: items,
        coverPath: coverPath,
        tagRefs: tagRefs,
        now: now,
      );
    } catch (e, st) {
      AppLogger.e(LogTag.storage, 'サンプルカタログの作成に失敗しました', e, st);
      return Result.failure(
        AppError.file('Failed to create sample catalog: $e'),
      );
    }
  }

  /// DocBook形式のウェルカムカタログを作成
  Future<Result<void, AppError>> _createDocBookTemplate(DateTime now) async {
    final docsDir = await getPrivateStorageDirectory();
    final libraryDir = await _fileService.getLibraryDirectory();
    final localeCode = await _resolveLocaleCode();
    final isJa = localeCode == 'ja';
    final dirName = isJa ? 'はじめてのCharmShelf' : 'Getting Started with CharmShelf';
    final dirPath = p.join(libraryDir.path, dirName);
    final relativeDirPath = p.relative(dirPath, from: docsDir.path);
    final dir = Directory(dirPath);

    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final items = <MediaItem>[];

    // 0. フォルダ自身のアイテムを追加 (LibraryViewModel で表示されるために必要)
    items.add(
      _createItem(
        relativeDirPath,
        isJa ? 'ようこそ' : 'Welcome',
        now,
        type: MediaType.folder,
      ),
    );

    // ガイド作成。Markdownで保存し、ビューアで見出し・箇条書きを読みやすく表示する。
    const aboutJa = '''
# CharmShelf へようこそ！ 🎉

## つなぎ、彩る。

ファイルのまとまりを「カタログ」に。
好きな「チャーム」をつけて、自分らしく、見つけやすく。

カタログは、ひとつのまとまりとして扱うファイルです。フォルダも単体ファイルもカタログにできます。チャームは、「旅行」「音楽」など、自分の目印です。カタログにいくつもつけて、好きな切り口から探せます。

## カタログとチャームを、こんなふうに使えます

- **写真をフォトブックに**：旅行や家族の写真を、1冊のようにまとめる
- **音楽をアルバムに**：音声ファイルをテーマや作品ごとにまとめる
- **イラストをイラスト集に**：作品や制作年ごとに見返せるカタログを作る
- **テキストを本に**：メモや資料を、あとで読む本として整理する

カタログには、チャーム、別名、ティア、メモ、お気に入り、カバー画像を設定できます。
元ファイルは元の場所に残したまま、CharmShelf内で見つけやすく整理できます。

まずは「02_HOW_TO_USE.md」を開いて、4つの例から気になるものを1つ試してみてください。
''';
    const aboutEn = '''
# Welcome to CharmShelf! 🎉

## Link and personalize.

Keep your files together in a catalog.
Add your favorite charms to make it yours and easy to find.

A catalog treats files as one unit. A folder or a single file can be a catalog. Charms are your own markers, such as Travel or Music. Add several to a catalog and find it by your favorite theme.

## What can you make with catalogs?

- **Turn photos into a photo book**: Keep travel or family photos together like one book.
- **Turn music into an album**: Group audio files by theme or release.
- **Turn illustrations into an art collection**: Make a catalog for works or a series.
- **Turn text into a book**: Organize notes and references as books to read later.

You can add charms, an alias, a tier, notes, favorites, and a cover image to a catalog.
Your original files stay where they are while CharmShelf makes them easier to find.

Open 02_HOW_TO_USE.md and try one of the four examples that sounds useful to you.
''';
    const howtoJa = '''
# カタログの使いかた 📖

## まずは共通の3ステップ

1. ライブラリを開き、＋からファイルまたはフォルダを選ぶ
2. フォルダをひとつのカタログとして取り込む。単体ファイルもカタログにできます
3. 自分の目印となるチャームをつける。別名、ティア、メモ、お気に入り、カバー画像も設定できます

取り込みではCharmShelf内にコピーを作ります。元ファイルは元の場所に残ります。

## 1. 写真をフォトブックに

例：2026年 春の旅行

- チャーム：旅行、写真、2026年
- 写真フォルダを1つのカタログとしてまとめる
- 後から「旅行」や「2026年」で探す

## 2. 音楽をアルバムに

例：作業用BGM、お気に入りのアルバム

- チャーム：音楽、お気に入り、作業用
- 音声ファイルをテーマや作品ごとにまとめる
- 一覧から開き、再生やミニプレーヤーを試す

## 3. イラストをイラスト集に

例：キャラクター設定画、2026年の作品

- チャーム：イラスト、作品、2026年
- 作品やシリーズごとにカタログを分ける
- カバー画像を設定して、カタログを見分けやすくする

## 4. テキストを本に

例：あとで読む資料、レシピ集

- チャーム：資料、読書、レシピ
- メモやPDF、テキストをテーマごとにまとめる
- 検索や絞り込みで必要な本を見つける

非表示は一覧上の整理機能で、ファイルの暗号化ではありません。共有端末ではアプリロックや端末ロックも使ってください。
''';
    const howtoEn = '''
# How to Use Catalogs 📖

## Start with these three steps

1. Open Library, tap +, and choose a file or folder.
2. Add a folder as one catalog. A single file can be a catalog too.
3. Add charms as your own markers. You can also set an alias, a tier, notes, favorites, and a cover image.

Adding creates a copy in CharmShelf. The original stays where it is.

## 1. Turn photos into a photo book

Example: Spring Trip 2026

- Charms: Travel, Photos, 2026
- Group one photo folder as a single catalog.
- Find it later with Travel or 2026.

## 2. Turn music into an album

Example: Focus Music or Favorite Album

- Charms: Music, Favorites, Focus
- Group audio files by theme or release.
- Open an item to try playback and the mini-player.

## 3. Turn illustrations into an art collection

Example: Character Designs or Works from 2026

- Charms: Illustration, Works, 2026
- Split catalogs by series or project.
- Set a cover image to make the catalog easy to recognize.

## 4. Turn text into a book

Example: Read Later or Recipe Book

- Charms: References, Reading, Recipes
- Group notes, PDFs, and text by theme.
- Use search and filters to find the book you need.

Hidden changes list visibility; it does not encrypt the file. On a shared device, also use app lock or the device lock.
''';
    final docs = {
      '01_ABOUT_APP.md': isJa ? aboutJa : aboutEn,
      '02_HOW_TO_USE.md': isJa ? howtoJa : howtoEn,
    };

    for (final entry in docs.entries) {
      final filePath = p.join(dirPath, entry.key);
      final file = File(filePath);
      await file.writeAsString(entry.value);
      items.add(
        _createItem(
          p.relative(filePath, from: docsDir.path), // 絶対パスから相対パスに変更
          entry.key,
          now,
          type: MediaType.file,
          parentPath: relativeDirPath, // 親フォルダを指定
        ),
      );
    }

    // 非表示ファイル
    final secretTitle = isJa ? '秘密のメモ.md' : 'Secret Memo.md';
    final secretPath = p.join(dirPath, secretTitle);
    final secretContent = isJa
        ? '''
# 秘密のメモ 🔐

おめでとうございます！非表示コンテンツを発見しました。

> 非表示は一覧上の整理機能で、暗号化ではありません。

共有端末ではアプリロックや端末ロックも使ってください。
'''
        : '''
# Secret Memo 🔐

Congrats! You found a hidden item.

> Hidden mode changes list visibility; it does not encrypt files.

Use app lock or the device lock on shared devices.
''';
    await File(secretPath).writeAsString(secretContent);
    items.add(
      _createItem(
        p.relative(secretPath, from: docsDir.path), // 絶対パスから相対パスに変更
        secretTitle,
        now,
        type: MediaType.file,
        isHidden: true,
        parentPath: relativeDirPath, // 親フォルダを指定
      ),
    );

    // アイコンコピー
    String? coverPath;
    try {
      final byteData = await rootBundle.load('assets/images/icon/icon.png');
      final bytes = byteData.buffer.asUint8List();
      const iconName = 'icon.png';
      final iconPath = p.join(dirPath, iconName);
      await File(iconPath).writeAsBytes(bytes);

      final relativeIconPath = p.relative(iconPath, from: docsDir.path);
      coverPath = relativeIconPath;
      // フォルダ自身のアイテムにもサムネイルパスを設定
      if (items.isNotEmpty) {
        items.first.thumbnailPath = relativeIconPath;
      }
      // 画像アイテムをリストに追加
      items.add(
        _createItem(
          relativeIconPath,
          isJa ? '公式アイコン' : 'Official Icon',
          now,
          type: MediaType.file,
          parentPath: relativeDirPath, // 親フォルダを指定
        ),
      );
    } catch (e) {
      AppLogger.e(LogTag.storage, 'アイコンコピー失敗: $e');
    }

    return _registerCollection(
      title: isJa ? 'はじめてのCharmShelf' : 'Getting Started with CharmShelf',
      alias: isJa ? 'ウェルカム・ガイド' : 'Welcome Guide',
      notes: isJa
          ? 'アプリの基本的な使い方を学べる公式ガイド本です。'
          : 'An official guidebook to learn the basics of the app.',
      dirName: dirName,
      // ウェルカムコンテンツはファイル形式ではなく、すべて「カタログ」として扱う。
      // 個別の形式（電子書籍・動画・音声）はコンテンツタイプのチャームで表現する。
      isCatalog: true,
      type: CollectionType.folder,
      items: items,
      coverPath: coverPath,
      tagRefs: const [
        _TemplateTagRef('保存版', facetName: '状態'),
        _TemplateTagRef('記事', facetName: 'コンテンツタイプ'),
        _TemplateTagRef('チュートリアル'),
      ],
      now: now,
    );
  }

  /// ビデオ形式のウェルカムカタログを作成 (ルート配置)
  Future<Result<void, AppError>> _createVideoTemplate(DateTime now) async {
    final docsDir = await getPrivateStorageDirectory();
    final libraryDir = await _fileService.getLibraryDirectory();
    const videoName = 'icon_move.mp4';
    final targetPath = p.join(libraryDir.path, videoName);
    final relativeTargetPath = p.relative(targetPath, from: docsDir.path);

    try {
      final byteData = await rootBundle.load('assets/videos/icon_move.mp4');
      await File(targetPath).writeAsBytes(byteData.buffer.asUint8List());
    } catch (e) {
      return Result.failure(AppError.file('ビデオアセットのコピーに失敗: $e'));
    }

    final items = [
      _createItem(
        relativeTargetPath,
        (await _resolveLocaleCode()) == 'ja' ? '動画を試す' : 'Try a Video',
        now,
        type: MediaType.file,
      ),
    ];

    final isJa = (await _resolveLocaleCode()) == 'ja';
    return _registerCollection(
      title: isJa ? '動画を試す' : 'Try a Video',
      alias: isJa ? '動画の再生例' : 'Video Playback Example',
      notes: isJa
          ? '一覧からタップして動画を開き、再生・一時停止・シークを試せるサンプルです。'
          : 'A sample for opening a video and trying play, pause, and seeking.',
      dirName: '',
      customPath: relativeTargetPath, // 動画ファイルの絶対パスから相対へ
      // ウェルカムコンテンツをカタログとして登録する。
      isCatalog: true,
      type: CollectionType.file,
      items: items,
      coverPath: null,
      tagRefs: const [
        _TemplateTagRef('映画', facetName: 'コンテンツタイプ'),
        _TemplateTagRef('保存版', facetName: '状態'),
        _TemplateTagRef('チュートリアル'),
      ],
      now: now,
    );
  }

  /// 音声形式のウェルカムカタログを作成 (ルート配置)
  Future<Result<void, AppError>> _createAudioTemplate(DateTime now) async {
    final docsDir = await getPrivateStorageDirectory();
    final libraryDir = await _fileService.getLibraryDirectory();
    const audioName = 'digital_shelf_life.mp3';
    final targetPath = p.join(libraryDir.path, audioName);
    final relativeTargetPath = p.relative(targetPath, from: docsDir.path);

    try {
      final byteData = await rootBundle.load(
        'assets/sounds/digital_shelf_life.mp3',
      );
      await File(targetPath).writeAsBytes(byteData.buffer.asUint8List());
    } catch (e) {
      AppLogger.w(
        LogTag.storage,
        '音声アセット digital_shelf_life.mp3 のコピーをスキップ（ファイル不在の可能性）: $e',
      );
      return Result.success(null); // 音声がない場合はスキップして正常終了とする
    }

    final items = [
      _createItem(
        relativeTargetPath,
        (await _resolveLocaleCode()) == 'ja' ? '音声を試す' : 'Try Audio',
        now,
        type: MediaType.file,
      ),
    ];

    final isJa = (await _resolveLocaleCode()) == 'ja';
    return _registerCollection(
      title: isJa ? '音声を試す' : 'Try Audio',
      alias: isJa ? '音声の再生例' : 'Audio Playback Example',
      notes: isJa
          ? '一覧からタップして音声を開き、再生・一時停止・ミニプレーヤーを試せるサンプルです。'
          : 'A sample for opening audio and trying play, pause, and the mini-player.',
      dirName: '',
      customPath: relativeTargetPath,
      // ウェルカムコンテンツをカタログとして登録する。
      isCatalog: true,
      type: CollectionType.file,
      items: items,
      coverPath: null,
      tagRefs: [
        _TemplateTagRef(
          isJa ? '音声カタログ' : 'Audio catalog',
          facetName: isJa ? 'コンテンツタイプ' : 'Content type',
          legacyName: isJa ? '音声チェイン' : 'Audio chain',
        ),
        const _TemplateTagRef('保存版', facetName: '状態'),
        const _TemplateTagRef('日本語', facetName: '言語/地域'),
        const _TemplateTagRef('チュートリアル'),
        const _TemplateTagRef('公式'),
      ],
      now: now,
    );
  }

  /// 共通の登録処理
  Future<Result<void, AppError>> _registerCollection({
    required String title,
    String? alias,
    String? notes,
    required String dirName,
    String? customPath,
    required bool isCatalog,
    required CollectionType type,
    required List<MediaItem> items,
    required String? coverPath,
    required List<_TemplateTagRef> tagRefs,
    required DateTime now,
  }) async {
    final docsDir = await getPrivateStorageDirectory();
    final libraryDir = await _fileService.getLibraryDirectory();
    final finalPath =
        customPath ??
        p.relative(p.join(libraryDir.path, dirName), from: docsDir.path);

    await _isar.writeTxn(() async {
      // 既存の同一パスのコレクションがないか確認
      final existingCollection = await _isar.mediaCollections
          .filter()
          .pathEqualTo(finalPath)
          .findFirst();

      if (existingCollection != null) {
        // 既存のアイテムを削除（重複防止）
        await existingCollection.items.load();
        for (final item in existingCollection.items) {
          await _isar.mediaItems.delete(item.id);
        }
      }

      final collection = (existingCollection ?? MediaCollection())
        ..uid = existingCollection?.uid ?? _uuid.v4()
        ..title = title
        ..alias = alias
        ..notes = notes
        ..path = finalPath
        ..type = type
        ..isCatalog = isCatalog
        ..isFavorite = true
        ..coverImagePath = coverPath
        ..createdAt = existingCollection?.createdAt ?? now
        ..updatedAt = now;

      await _isar.mediaCollections.put(collection);

      final facets = await _isar.collection<TagFacet>().where().findAll();
      final facetByName = {for (final facet in facets) facet.name: facet.id};
      final keyedTagRefs = tagRefs
          .where((ref) => ref.facetName != null)
          .toList();
      final unkeyedTagRefs = tagRefs
          .where((ref) => ref.facetName == null)
          .toList();

      final tagKeys = keyedTagRefs
          .expand((ref) {
            final facetId = facetByName[ref.facetName!];
            if (facetId == null) {
              return const <String>[];
            }
            return [
              Tag.buildKey(facetId, ref.name),
              if (ref.legacyName != null)
                Tag.buildKey(facetId, ref.legacyName!),
            ];
          })
          .toSet()
          .toList();
      final tagNames = unkeyedTagRefs.map((ref) => ref.name).toSet().toList();
      final tagsByKey = tagKeys.isEmpty
          ? <Tag>[]
          : await _isar.tags
                .filter()
                .anyOf(tagKeys, (q, String key) => q.keyEqualTo(key))
                .findAll();
      final tagsByName = tagNames.isEmpty
          ? <Tag>[]
          : await _isar.tags
                .filter()
                .anyOf(tagNames, (q, String name) => q.nameEqualTo(name))
                .findAll();
      final tagByKey = {for (final tag in tagsByKey) tag.key: tag};
      final selectedKeyedTags = keyedTagRefs.map((ref) {
        final facetId = facetByName[ref.facetName!];
        if (facetId == null) return null;
        return tagByKey[Tag.buildKey(facetId, ref.name)] ??
            (ref.legacyName == null
                ? null
                : tagByKey[Tag.buildKey(facetId, ref.legacyName!)]);
      }).whereType<Tag>();
      final tags = <int, Tag>{
        for (final tag in selectedKeyedTags) tag.id: tag,
        for (final tag in tagsByName) tag.id: tag,
      }.values;
      collection.tags.clear();
      for (final tag in tags) {
        collection.tags.add(tag);
      }
      await collection.tags.save();

      // アイテムの紐付け
      collection.items.clear();
      for (final item in items) {
        item.uid = _uuid.v4();
        await _isar.mediaItems.put(item);
        collection.items.add(item);
      }
      await collection.items.save();
    });
    return Result.success(null);
  }

  MediaItem _createItem(
    String path, // 相対パスを受け取る
    String title,
    DateTime now, {
    required MediaType type,
    bool isHidden = false,
    String? parentPath,
  }) {
    return MediaItem()
      ..path = path
      ..parentPath = parentPath
      ..originalPath = 'template://welcome/$title'
      ..sourceType = MediaSourceType.localCopy
      ..addedAt = now
      ..updatedAt = now
      ..type = type
      ..isHidden = isHidden;
  }

  /// 既存の動画カバー指定をnullに修復する（過去のバグ修正用）
  Future<bool> repairLegacyCovers() async {
    try {
      final collections = await _isar.mediaCollections
          .filter()
          .coverImagePathEqualTo('library/icon_move.mp4')
          .findAll();

      if (collections.isNotEmpty) {
        AppLogger.i(
          LogTag.storage,
          '過去の不正なカバー画像指定を検知しました。修復を開始します。件数: ${collections.length}',
        );
        await _isar.writeTxn(() async {
          for (final col in collections) {
            col.coverImagePath = null;
            col.updatedAt = DateTime.now();
            await _isar.mediaCollections.put(col);
          }
        });
        AppLogger.i(LogTag.storage, 'カバー画像の修復が完了しました。');
      }
      return true;
    } catch (e, st) {
      AppLogger.w(LogTag.storage, 'カバー画像の修復処理中にエラーが発生しました', e, st);
      return false;
    }
  }

  /// 不正にコレクション登録されてしまったルートフォルダ (library) を削除・修復する
  Future<bool> repairInvalidRootCollections() async {
    try {
      final invalidCollections = await _isar.mediaCollections
          .filter()
          .pathEqualTo('library')
          .findAll();

      if (invalidCollections.isNotEmpty) {
        AppLogger.i(
          LogTag.storage,
          '不正なルートコレクション (library) を検知しました。削除を開始します。件数: ${invalidCollections.length}',
        );
        await _isar.writeTxn(() async {
          for (final col in invalidCollections) {
            await _isar.mediaCollections.delete(col.id);
          }
        });
        AppLogger.i(LogTag.storage, '不正なルートコレクションの削除が完了しました。');
      }
      return true;
    } catch (e, st) {
      AppLogger.w(LogTag.storage, '不正なルートコレクションの修復処理中にエラーが発生しました', e, st);
      return false;
    }
  }

  /// 既存環境の Welcome_DocBook を新名称（はじめてのCharmShelf）にマイグレーションする
  Future<bool> repairLegacyWelcomeDirectory() async {
    try {
      var succeeded = true;
      final docsDir = await getPrivateStorageDirectory();
      final libraryDir = await _fileService.getLibraryDirectory();

      const oldDirName = 'Welcome_DocBook';
      final oldDirPath = p.join(libraryDir.path, oldDirName);
      final oldRelativeDirPath = p.relative(oldDirPath, from: docsDir.path);

      final oldDir = Directory(oldDirPath);
      final oldCollection = await _isar.mediaCollections
          .filter()
          .pathEqualTo(oldRelativeDirPath)
          .findFirst();

      // ディレクトリもコレクションも存在しない場合はマイグレーション不要
      if (!oldDir.existsSync() && oldCollection == null) {
        return true;
      }

      final localeCode = await _resolveLocaleCode();
      final isJa = localeCode == 'ja';
      final newDirName = isJa
          ? 'はじめてのCharmShelf'
          : 'Getting Started with CharmShelf';
      final newDirPath = p.join(libraryDir.path, newDirName);
      final newRelativeDirPath = p.relative(newDirPath, from: docsDir.path);

      AppLogger.i(
        LogTag.storage,
        '旧ウェルカムディレクトリ ($oldDirName) を検知しました。マイグレーションを開始します: $newDirName',
      );

      // 1. 物理ディレクトリのリネーム
      if (oldDir.existsSync()) {
        if (!Directory(newDirPath).existsSync()) {
          final moveResult = await _fileService.moveEntity(
            oldRelativeDirPath,
            newRelativeDirPath,
          );
          if (moveResult.isFailure) {
            succeeded = false;
            AppLogger.w(
              LogTag.storage,
              '物理ディレクトリの移動に失敗しました: ${moveResult.errorOrNull}',
            );
          }
        }
      }

      // 2. Isar データベースの更新
      await _isar.writeTxn(() async {
        // コレクションの更新
        if (oldCollection != null) {
          final newCollection = await _isar.mediaCollections
              .filter()
              .pathEqualTo(newRelativeDirPath)
              .findFirst();

          final newDirExists = Directory(newDirPath).existsSync();

          if (newCollection != null && newCollection.id != oldCollection.id) {
            // 既に新名称のコレクションが存在する場合は重複した旧コレクションを削除
            await _isar.mediaCollections.delete(oldCollection.id);
          } else if (!newDirExists && !oldDir.existsSync()) {
            // 物理フォルダがどちらも存在しない場合は旧コレクションを削除
            await _isar.mediaCollections.delete(oldCollection.id);
          } else {
            oldCollection.path = newRelativeDirPath;
            if (oldCollection.title == oldDirName ||
                oldCollection.title == 'はじめてのCharmShelf' ||
                oldCollection.title == 'Getting Started with CharmShelf') {
              oldCollection.title = newDirName;
            }
            if (oldCollection.coverImagePath != null &&
                oldCollection.coverImagePath!.startsWith(oldRelativeDirPath)) {
              oldCollection.coverImagePath = oldCollection.coverImagePath!
                  .replaceFirst(oldRelativeDirPath, newRelativeDirPath);
            }
            // カバー画像の実在確認
            if (oldCollection.coverImagePath != null) {
              final coverFile = File(
                p.join(docsDir.path, oldCollection.coverImagePath!),
              );
              if (!coverFile.existsSync()) {
                oldCollection.coverImagePath = null;
              }
            }
            oldCollection.updatedAt = DateTime.now();
            await _isar.mediaCollections.put(oldCollection);
          }
        }

        // MediaItem の更新（フォルダ自身および配下ファイル）
        final items = await _isar.mediaItems
            .filter()
            .pathStartsWith(oldRelativeDirPath)
            .or()
            .parentPathEqualTo(oldRelativeDirPath)
            .findAll();

        for (final item in items) {
          if (item.path == oldRelativeDirPath) {
            item.path = newRelativeDirPath;
          } else if (item.path.startsWith('$oldRelativeDirPath/')) {
            item.path = item.path.replaceFirst(
              oldRelativeDirPath,
              newRelativeDirPath,
            );
          }
          if (item.parentPath == oldRelativeDirPath) {
            item.parentPath = newRelativeDirPath;
          }
          item.updatedAt = DateTime.now();
          await _isar.mediaItems.put(item);
        }
      });

      if (succeeded) {
        AppLogger.i(LogTag.storage, '旧ウェルカムディレクトリのマイグレーションが完了しました。');
      } else {
        AppLogger.w(LogTag.storage, '旧ウェルカムディレクトリの修復が一部完了しませんでした。次回再試行します。');
      }
      return succeeded;
    } catch (e, st) {
      AppLogger.w(LogTag.storage, '旧ウェルカムディレクトリの修復処理中にエラーが発生しました', e, st);
      return false;
    }
  }
}

class _TemplateTagRef {
  final String name;
  final String? facetName;
  final String? legacyName;

  const _TemplateTagRef(this.name, {this.facetName, this.legacyName});
}

class _TemplateAsset {
  final String assetPath;
  final String fileName;
  final String title;

  const _TemplateAsset({
    required this.assetPath,
    required this.fileName,
    required this.title,
  });
}

Future<String> _resolveLocaleCode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('app_locale');
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
  } catch (_) {
    // ignore
  }
  final locale = ui.PlatformDispatcher.instance.locale;
  final code = locale.languageCode.toLowerCase();
  return (code == 'ja') ? 'ja' : 'en';
}
