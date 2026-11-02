import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/features/device_files/presentation/device_files_screen.dart';
import 'package:private_shelf/features/library/presentation/helpers/system_file_picker.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/file_tree.dart';
import 'package:private_shelf/features/library/domain/models/selected_document.dart';
import 'package:private_shelf/features/library/presentation/helpers/device_file_actions.dart';
import 'package:private_shelf/features/library/presentation/helpers/library_action_handler.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/import_flow_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/import_selection_screen.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';

import '../../../../shared/finders.dart' as shared_find;

class _Picker extends SystemFilePicker {
  final calls = <DeviceFileAction>[];
  final released = <Uri>[];
  Completer<List<SelectedDocument>?>? pending;
  Completer<PickedFolder?>? pendingFolder;
  List<SelectedDocument>? selectedDocuments;
  PickedFolder? selectedFolder;
  bool fail = false;

  @override
  Future<SelectedDocument?> openFile() async {
    calls.add(DeviceFileAction.open);
    if (fail) throw PlatformException(code: 'secret-path-do-not-display');
    return null;
  }

  @override
  Future<List<SelectedDocument>?> pickFiles() async {
    calls.add(DeviceFileAction.importFiles);
    return pending?.future ?? selectedDocuments;
  }

  @override
  Future<PickedFolder?> pickFolder() async {
    calls.add(DeviceFileAction.importFolder);
    return pendingFolder?.future ?? selectedFolder;
  }

  @override
  Future<void> releaseDocuments(List<SelectedDocument> documents) async {
    released.addAll(
      documents
          .where((document) => document.ownsGrant)
          .map((document) => document.uri),
    );
  }

  @override
  Future<void> releaseFolder(PickedFolder folder) async {
    if (folder.ownsGrant) released.add(folder.uri);
  }
}

class _Flow extends ImportFlowNotifier {
  List<SelectedDocument>? documents;
  Uri? folder;
  String? target;
  bool? ownsFolderGrant;
  Completer<void>? pendingScan;

  @override
  ImportFlowState build() => ImportFlowState();

  @override
  Future<void> restoreDraftSession() async {}

  @override
  Future<void> startDocumentsScan(
    List<SelectedDocument> documents, {
    String? targetParentPath,
  }) async {
    this.documents = documents;
    target = targetParentPath;
    _confirm();
  }

  @override
  Future<void> startScan(
    Uri uri, {
    String? targetParentPath,
    bool ownsGrant = false,
  }) async {
    folder = uri;
    target = targetParentPath;
    ownsFolderGrant = ownsGrant;
    state = ImportFlowState(status: ImportFlowStatus.scanning);
    await pendingScan?.future;
    _confirm();
  }

  void _confirm() {
    state = ImportFlowState(
      status: ImportFlowStatus.confirming,
      rootNode: FileTreeNode(
        name: 'selection',
        uri: Uri.parse('private-shelf://selection'),
        relativePath: '',
        isDirectory: true,
        isMedia: true,
      ),
    );
  }
}

class _Filter extends MediaFilterNotifier {
  @override
  MediaFilter build(AppMode mode) =>
      const MediaFilter(parentPath: 'destination');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(AppSnackBarMessenger.clearGlobal);

  Future<void> show(
    WidgetTester tester,
    _Picker picker, {
    Locale locale = const Locale('ja'),
    double scale = 1,
    String? addAction,
    ValueNotifier<bool>? visible,
    _Flow? flow,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          systemFilePickerProvider.overrideWithValue(picker),
          systemFilePickerIsAndroidProvider.overrideWithValue(true),
          if (flow != null) importFlowNotifierProvider.overrideWith(() => flow),
          mediaFilterNotifierProvider(
            AppMode.internal,
          ).overrideWith(_Filter.new),
          hapticsEnabledProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible ?? ValueNotifier(true),
              builder: (context, isVisible, _) => !isVisible
                  ? const SizedBox()
                  : Consumer(
                      builder: (context, ref, _) => TextButton(
                        child: const Text('Device'),
                        onPressed: () => addAction == null
                            ? showDeviceFileActions(context, ref)
                            : const LibraryActionHandler().handleAddAction(
                                addAction,
                                context,
                                ref,
                              ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final action in DeviceFileAction.values) {
    testWidgets(
      'device menu dispatches $action directly and cancel stays on host',
      (tester) async {
        final picker = _Picker();
        await show(tester, picker);
        await tester.tap(find.text('Device'));
        await tester.pumpAndSettle();
        expect(shared_find.findAppText('ファイルを開く'), findsOneWidget);
        expect(shared_find.findAppText('ファイルを取り込む'), findsOneWidget);
        expect(shared_find.findAppText('フォルダを取り込む'), findsOneWidget);
        expect(find.text('以前の候補（引継ぎ用）'), findsNothing);
        final label = switch (action) {
          DeviceFileAction.open => 'ファイルを開く',
          DeviceFileAction.importFiles => 'ファイルを取り込む',
          DeviceFileAction.importFolder => 'フォルダを取り込む',
        };
        await tester.tap(shared_find.findAppText(label));
        await tester.pumpAndSettle();
        expect(picker.calls, [action]);
        expect(find.text('Device'), findsOneWidget);
        expect(find.byType(DeviceFilesScreen), findsNothing);
      },
    );
  }

  for (final entry in ['import_file', 'import_folder']) {
    testWidgets(
      'add $entry opens the appropriate picker without another menu',
      (tester) async {
        final picker = _Picker();
        await show(tester, picker, addAction: entry);
        await tester.tap(find.text('Device'));
        await tester.pumpAndSettle();
        expect(picker.calls, [
          entry == 'import_file'
              ? DeviceFileAction.importFiles
              : DeviceFileAction.importFolder,
        ]);
        expect(shared_find.findAppText('ファイルを開く'), findsNothing);
        expect(find.byType(DeviceFilesScreen), findsNothing);
      },
    );
  }

  for (final locale in ['ja', 'en']) {
    testWidgets('three-action menu fits 320dp at 200% in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, _Picker(), locale: Locale(locale), scale: 2);
      await tester.tap(find.text('Device'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'failure shows a safe message rather than behaving as cancellation',
    (tester) async {
      await show(tester, _Picker()..fail = true);
      await tester.tap(find.text('Device'));
      await tester.pumpAndSettle();
      await tester.tap(shared_find.findAppText('ファイルを開く'));
      await tester.pumpAndSettle();
      expect(
        find.text('ファイルを選択できませんでした。保存場所やアクセスを確認し、もう一度お試しください。'),
        findsOneWidget,
      );
      expect(find.textContaining('secret-path'), findsNothing);
    },
  );

  testWidgets('a result after host disposal releases only newly owned grants', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    final picker = _Picker()..pending = Completer<List<SelectedDocument>?>();
    await show(tester, picker, addAction: 'import_file', visible: visible);
    await tester.tap(find.text('Device'));
    await tester.pump();
    visible.value = false;
    await tester.pump();
    final owned = Uri.parse('content://provider/document/new');
    picker.pending!.complete([
      SelectedDocument(uri: owned, name: 'new.jpg', ownsGrant: true),
      SelectedDocument(
        uri: Uri.parse('content://provider/document/existing'),
        name: 'existing.jpg',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(picker.released, [owned]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selected files go to confirmation with the current destination',
    (tester) async {
      final flow = _Flow();
      final document = SelectedDocument(
        uri: Uri.parse('content://provider/document/new'),
        name: 'photo',
        mimeType: 'image/png',
        ownsGrant: true,
      );
      final picker = _Picker()..selectedDocuments = [document];
      await show(tester, picker, addAction: 'import_file', flow: flow);
      await tester.tap(find.text('Device'));
      await tester.pumpAndSettle();

      expect(flow.documents, [document]);
      expect(flow.target, 'destination');
      expect(find.byType(ImportSelectionScreen), findsOneWidget);
      expect(picker.released, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected folders show scanning while the flow adopts the grant',
    (tester) async {
      final flow = _Flow()..pendingScan = Completer<void>();
      final folder = PickedFolder(
        uri: Uri.parse('content://provider/tree/new'),
        ownsGrant: true,
      );
      final picker = _Picker()..selectedFolder = folder;
      await show(tester, picker, addAction: 'import_folder', flow: flow);
      await tester.tap(find.text('Device'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(flow.folder, folder.uri);
      expect(flow.target, 'destination');
      expect(flow.ownsFolderGrant, isTrue);
      expect(find.byType(ImportSelectionScreen), findsOneWidget);
      expect(picker.released, isEmpty);
      flow.pendingScan!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ImportSelectionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a folder picked after host disposal releases its new grant', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    final picker = _Picker()..pendingFolder = Completer<PickedFolder?>();
    await show(tester, picker, addAction: 'import_folder', visible: visible);
    await tester.tap(find.text('Device'));
    await tester.pump();
    visible.value = false;
    await tester.pump();
    final uri = Uri.parse('content://provider/tree/new');
    picker.pendingFolder!.complete(PickedFolder(uri: uri, ownsGrant: true));
    await tester.pumpAndSettle();
    expect(picker.released, [uri]);
    expect(tester.takeException(), isNull);
  });
}
