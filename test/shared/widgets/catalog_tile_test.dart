import '../../helpers/visual_review_capture.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_list_view.dart';
import 'package:private_shelf/features/settings/domain/models/privacy_settings.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/catalog_tile.dart';
import 'package:private_shelf/shared/widgets/text/file_name_text.dart';

class _Collection extends CollectionNotifier {
  _Collection(this.collection);
  final MediaCollection? collection;

  @override
  Future<MediaCollection?> build(String path) async => collection;
}

class _Privacy extends PrivacySettingsNotifier {
  _Privacy(this.secret);
  final bool secret;

  @override
  Future<PrivacySettings> build() async =>
      PrivacySettings(useSecretThumbnailMode: secret);
}

MediaItem _file(String name) => MediaItem()
  ..id = 1
  ..path = 'library/$name'
  ..type = MediaType.file
  ..sourceType = MediaSourceType.localCopy;

Future<void> _pump(
  WidgetTester tester, {
  required MediaItem item,
  bool simple = false,
  bool secret = false,
  bool selectionMode = false,
  String? cover,
  String? documentsPath,
  bool throughLibrary = false,
  bool provideItem = true,
  double textScale = 1,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
}) async {
  if (reviewFontsEnabled) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  final collection = throughLibrary || !provideItem
      ? (MediaCollection()
          ..path = item.path
          ..title = item.path.split('/').last
          ..type = CollectionType.file
          ..isCatalog = true)
      : null;
  item.collection.value = collection;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hapticsEnabledProvider.overrideWith((ref) => false),
        appDocumentsPathSyncProvider.overrideWithValue(documentsPath ?? '/tmp'),
        collectionNotifierProvider(
          item.path,
        ).overrideWith(() => _Collection(collection)),
        privacySettingsNotifierProvider.overrideWith(() => _Privacy(secret)),
        globalSimpleDisplayProvider.overrideWith((ref) => simple),
      ],
      child: MaterialApp(
        theme: reviewTheme(),
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: RepaintBoundary(key: reviewBoundaryKey, child: child!),
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: throughLibrary
                  ? MediaListView(
                      items: [item],
                      appMode: AppMode.internal,
                      filterOverride: const MediaFilter(onlyCatalogs: true),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        CatalogTile(
                          path: item.path,
                          title: item.path.split('/').last,
                          isFavorite: false,
                          tier: MediaTier.none,
                          type: provideItem ? item.type : null,
                          item: provideItem ? item : null,
                          coverImagePath: cover,
                          isSimpleDisplay: simple,
                          isSelectionMode: selectionMode,
                          onTap: onTap,
                          onLongPress: onLongPress,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadReviewFonts);
  for (final simple in [false, true]) {
    for (final entry in [
      (name: 'sound.mp3', icon: Icons.audiotrack, label: '音声 · MP3'),
      (name: 'photo.png', icon: Icons.image, label: '画像 · PNG'),
      (name: 'movie.mp4', icon: Icons.movie, label: '動画 · MP4'),
      (name: 'book.pdf', icon: Icons.description, label: '文書 · PDF'),
      (name: 'README.md', icon: Icons.description, label: '文書 · MD'),
      (name: 'notes.yaml', icon: Icons.description, label: '文書 · YAML'),
      (name: 'unknown.xyz', icon: Icons.insert_drive_file, label: 'ファイル · XYZ'),
    ]) {
      testWidgets('${entry.name} remains identifiable, simple=$simple', (
        tester,
      ) async {
        await _pump(tester, item: _file(entry.name), simple: simple);
        expect(find.byIcon(entry.icon), findsOneWidget);
        expect(find.text(entry.label), findsOneWidget);
        if (!simple) await captureReview(tester, 'catalog-${entry.name}');
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the library chain route uses an audio fallback', (tester) async {
    await _pump(
      tester,
      item: _file('sound.mp3'),
      simple: true,
      throughLibrary: true,
    );
    expect(find.byType(CatalogTile), findsOneWidget);
    expect(find.byIcon(Icons.audiotrack), findsOneWidget);
    expect(find.byIcon(Icons.image), findsNothing);
    expect(find.text('音声 · MP3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('audio MIME and original name work without a stored extension', (
    tester,
  ) async {
    final item = _file('opaque-name')
      ..mimeType = 'audio/mpeg'
      ..originalPath = 'sound.mp3';
    await _pump(tester, item: item);
    expect(find.byIcon(Icons.audiotrack), findsOneWidget);
    expect(find.text('音声 · MP3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a collection without a loaded item uses its original path', (
    tester,
  ) async {
    await _pump(
      tester,
      item: _file('sound.mp3'),
      provideItem: false,
      simple: true,
    );
    expect(find.byIcon(Icons.audiotrack), findsOneWidget);
    expect(find.text('音声 · MP3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a folder is not classified from its name extension', (
    tester,
  ) async {
    await _pump(tester, item: _file('a-folder.mp3')..type = MediaType.folder);
    expect(find.byIcon(Icons.folder_rounded), findsOneWidget);
    expect(find.byIcon(Icons.audiotrack), findsNothing);
    expect(find.text('音声 · MP3'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final coverState in ['valid', 'missing', 'invalid', 'secret']) {
    testWidgets('audio cover=$coverState keeps its file type', (tester) async {
      final directory = Directory.systemTemp.createTempSync('catalog-cover-');
      addTearDown(() => directory.deleteSync(recursive: true));
      if (coverState != 'missing') {
        File('${directory.path}/cover.png').writeAsBytesSync(
          coverState == 'invalid'
              ? [0, 1, 2]
              : base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
                ),
        );
      }
      Object? decodeError;
      // Start FileImage resolution in the real async zone as well as waiting
      // there. Joining an image first resolved in FakeAsync cannot finish I/O.
      Future<void> pumpAndDecode() async {
        await _pump(
          tester,
          item: _file('sound.mp3'),
          cover: 'cover.png',
          documentsPath: directory.path,
          secret: coverState == 'secret',
        );
        if (coverState == 'valid' || coverState == 'invalid') {
          final imageElement = tester.element(find.byType(Image));
          final image = imageElement.widget as Image;
          await precacheImage(
            image.image,
            imageElement,
            onError: (error, stackTrace) => decodeError = error,
          ).timeout(const Duration(seconds: 10));
        }
      }

      if (coverState == 'valid' || coverState == 'invalid') {
        await tester.runAsync(pumpAndDecode);
      } else {
        await pumpAndDecode();
      }
      if (coverState == 'valid' || coverState == 'invalid') {
        expect(decodeError, coverState == 'invalid' ? isNotNull : isNull);
      }
      await tester.pumpAndSettle();
      expect(find.text('音声 · MP3'), findsOneWidget);
      if (coverState == 'valid') {
        expect(find.byType(Image), findsOneWidget);
        expect(find.byIcon(Icons.audiotrack), findsNothing);
      } else {
        expect(find.byIcon(Icons.audiotrack), findsOneWidget);
        if (coverState == 'secret') expect(find.byType(Image), findsNothing);
      }
      expect(find.byIcon(Icons.image), findsNothing);
      await captureReview(tester, 'catalog-cover-$coverState');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'a long name keeps its suffix and opens the complete selectable name',
    (tester) async {
      const name = '共通のとても長い接頭辞_20261006_旅行で集めたお気に入りの音声.mp3';
      final item = _file(name);
      var opens = 0;
      var longPresses = 0;
      await _pump(
        tester,
        item: item,
        textScale: 2,
        onTap: () => opens++,
        onLongPress: () => longPresses++,
      );
      final title = tester.widget<Text>(
        find.descendant(
          of: find.byType(FileNameText),
          matching: find.byType(Text),
        ),
      );
      expect(title.data, contains('…'));
      expect(title.data, endsWith('.mp3'));
      expect(title.semanticsLabel, name);
      await captureReview(tester, 'catalog-long-name-200pct');

      final info = find.byKey(ValueKey('catalog-file-info-${item.path}'));
      expect(tester.getSize(info).height, greaterThanOrEqualTo(44));
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        name,
      );
      expect(opens, 0);
      await captureReview(tester, 'catalog-full-name-dialog-200pct');
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FileNameText));
      await tester.longPress(find.byType(FileNameText));
      expect(opens, 1);
      expect(longPresses, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('file information does not interrupt selection mode', (
    tester,
  ) async {
    final item = _file('sound.mp3');
    await _pump(tester, item: item, selectionMode: true);
    final button = tester.widget<TextButton>(
      find.byKey(ValueKey('catalog-file-info-${item.path}')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('音声 · MP3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
