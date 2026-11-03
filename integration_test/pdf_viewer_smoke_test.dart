import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_viewer_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/external_file_preview_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/media_viewer_screen.dart';
import 'package:private_shelf/features/library/presentation/widgets/pdf_viewer.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer_state_panel.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer/pdf_selection_handle.dart';

import '../test/helpers/test_helpers.dart';
import 'support/pdf_fixture.dart';

/// Use a dedicated Simulator/emulator or an explicitly verified, fresh QA
/// package on a physical device. This entry point never
/// starts app.main, opens the app database, imports files, or launches URLs.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PDF touch interaction inside the full preview route', (
    tester,
  ) async {
    final directory = await (await getTemporaryDirectory()).createTemp(
      'pdf-touch-qa-',
    );
    final file = await File('${directory.path}/touch.pdf')
        .writeAsBytes(pdfFixture());
    final item = MediaItem()
      ..id = -918274
      ..path = file.uri.toString()
      ..originalPath = 'touch.pdf'
      ..isImportPreview = true
      ..mimeType = 'application/pdf';
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await directory.delete(recursive: true);
    });
    await tester.pumpWidget(
      createProviderApp(
        MediaViewerScreen(initialItem: item),
        overrides: [
          appDocumentsPathSyncProvider.overrideWith((ref) => directory.path),
          externalFilePreviewProvider(item).overrideWith((ref) => file.path),
          collectionNotifierProvider(item.path)
              .overrideWith(_PreviewCollection.new),
          mediaViewerViewModelProvider.overrideWith(_PreviewViewModel.new),
        ],
      ),
    );
    await _until(tester, () {
      final widgets = find.byType(pdfrx.PdfViewer).evaluate();
      return widgets.isNotEmpty &&
          (widgets.single.widget as pdfrx.PdfViewer).controller!.isReady;
    });
    await tester.pumpAndSettle();
    final controller = tester
        .widget<pdfrx.PdfViewer>(find.byType(pdfrx.PdfViewer))
        .controller!;
    final links = await controller.pages.first.loadLinks(
      enableAutoLinkDetection: false,
    );
    final internal = links.singleWhere((link) => link.dest != null);
      final external = links.singleWhere((link) => link.url != null);
      final box = tester.renderObject<RenderBox>(find.byType(pdfrx.PdfViewer));
      final externalRect = controller.calcRectForRectInsidePage(
        pageNumber: 1,
        rect: external.rects.first,
      );
      await tester.tapAt(
        box.localToGlobal(controller.documentToLocal(externalRect.center)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('https://example.invalid/charmshelf-pdf-qa'), findsOneWidget);
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
    final rect = controller.calcRectForRectInsidePage(
      pageNumber: 1,
      rect: internal.rects.first,
    );
    await tester.tapAt(
      box.localToGlobal(controller.documentToLocal(rect.center)),
    );
      // pdfrx also recognizes double taps; let a single tap be dispatched.
      await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      controller.pageNumber,
      2,
      reason: 'An actual annotation tap must navigate inside the preview',
    );
    await controller.goToPage(pageNumber: 1, duration: Duration.zero);
    await tester.pumpAndSettle();
    final text = (await controller.pages.first.loadText())!;
    final character = text.charRects[text.fullText.indexOf('Selectable') + 2];
    final textRect = controller.calcRectForRectInsidePage(
      pageNumber: 1,
      rect: character,
    );
    await tester.longPressAt(
      box.localToGlobal(controller.documentToLocal(textRect.center)),
    );
    await tester.pumpAndSettle();
    final selected = await controller.textSelectionDelegate.getSelectedText();
    expect(selected, contains('Selectable'));
    expect(find.byType(PdfSelectionHandle), findsNWidgets(2));
      if (const bool.fromEnvironment('CHARMSHELF_PDF_QA_VISUAL_PAUSE')) {
        debugPrint('CHARMSHELF_PDF_QA_SELECTION_READY');
        await tester.pump(const Duration(seconds: 30));
      }
    final before = controller.value.clone();
    final handle = find.byWidgetPredicate(
      (widget) => widget is PdfSelectionHandle && !widget.isStart,
    );
    await tester.drag(handle, const Offset(70, 0));
    await tester.pumpAndSettle();
    expect(
      controller.value,
      before,
      reason: 'Dragging a selection handle must not pan the PDF',
    );
    expect(
        (await controller.textSelectionDelegate.getSelectedText()).length,
        greaterThan(selected.length),
    );
    await controller.textSelectionDelegate.clearTextSelection();
    await tester.pumpAndSettle();
    final dismissible = find.byKey(const Key('media_viewer_dismissible'));
    expect(
      tester.widget<Dismissible>(dismissible).direction,
      DismissDirection.none,
    );
    final origin = tester.getTopLeft(find.byType(pdfrx.PdfViewer));
      final beforeScroll = controller.value.clone();
      await tester.drag(find.byType(pdfrx.PdfViewer), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(controller.value, isNot(beforeScroll), reason: 'The PDF itself must still scroll');
      expect(tester.getTopLeft(find.byType(pdfrx.PdfViewer)), origin);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(pdfrx.PdfViewer)),
    );
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byType(pdfrx.PdfViewer)),
      origin,
      reason: 'Dragging the PDF must not move the preview route',
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('native PDF rendering, selection, links and failure recovery', (
    tester,
  ) async {
    expect(Platform.isIOS || Platform.isAndroid, isTrue);
    final directory = await (await getTemporaryDirectory()).createTemp(
      'pdf-qa-',
    );
    final plain = await File('${directory.path}/plain.pdf')
        .writeAsBytes(pdfFixture());
    final protected = await File('${directory.path}/protected.pdf')
        .writeAsBytes(pdfFixture(encrypted: true));
    final broken = await File('${directory.path}/broken.pdf')
        .writeAsString('synthetic invalid PDF');
    final originalHash = sha256.convert(await plain.readAsBytes());
    final protectedHash = sha256.convert(await protected.readAsBytes());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      // Only this test's newly created temporary directory is removed.
      await directory.delete(recursive: true);
    });

    var ready = 0;
    Future<void> show(File file) async {
      final item = MediaItem()
        ..id = 918273
        ..path = file.uri.pathSegments.last
        ..originalPath = file.uri.pathSegments.last
        ..sourceType = MediaSourceType.localCopy
        ..type = MediaType.file;
      await tester.pumpWidget(
        createProviderApp(
          PdfViewer(item: item, onContentReady: () => ready++),
          overrides: [
            appDocumentsPathSyncProvider.overrideWith((ref) => directory.path),
          ],
        ),
      );
    }

    await show(plain);
    await _until(tester, () => ready == 1);
    final viewer = tester.widget<pdfrx.PdfViewer>(find.byType(pdfrx.PdfViewer));
    final controller = viewer.controller!;
    expect(controller.pageCount, 2);
    expect(
      (await controller.pages.first.loadText())!.fullText,
      contains('Selectable synthetic text'),
    );
    final image = await controller.pages.first.render(
      fullWidth: 200,
      fullHeight: 250,
    );
    expect(image, isNotNull);
    expect(
      image!.pixels.toSet().length,
      greaterThan(2),
      reason: 'Rendered pixels must contain text, not only a blank page',
    );
    image.dispose();

    final zoom = controller.currentZoom;
    await controller.zoomUp(duration: Duration.zero);
    await tester.pumpAndSettle();
    expect(controller.currentZoom, greaterThan(zoom));
    if (const bool.fromEnvironment('CHARMSHELF_PDF_QA_VISUAL_PAUSE')) {
      // Optional checkpoint for a host screenshot of the settled zoomed viewer.
      // Keep this synthetic-only entry point on a dedicated Simulator/emulator.
      debugPrint('CHARMSHELF_PDF_QA_ZOOM_READY');
      await tester.pump(const Duration(seconds: 30));
    }
    await controller.textSelectionDelegate.selectAllText();
    expect(
      await controller.textSelectionDelegate.getSelectedText(),
      contains('Selectable synthetic text'),
    );
    await controller.textSelectionDelegate.clearTextSelection();

    final links = await controller.pages.first.loadLinks(
      enableAutoLinkDetection: false,
    );
    expect(links, hasLength(2));
    // Exercise the app callback with the real PDFium-decoded annotation.
    viewer.params.linkHandlerParams!.onLinkTap(
      links.singleWhere((link) => link.url != null),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('https://example.invalid/charmshelf-pdf-qa'),
      findsOneWidget,
    );
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.byType(pdfrx.PdfViewer), findsOneWidget);
    viewer.params.linkHandlerParams!.onLinkTap(
      links.singleWhere((link) => link.dest != null),
    );
    await tester.pumpAndSettle();
    expect(controller.pageNumber, 2);

    await show(protected);
    await _enterPassword(tester, 'wrong-synthetic');
    await _until(
      tester,
      () => find.text('パスワードが違います。もう一度入力してください。').evaluate().isNotEmpty,
    );
    expect(ready, 1);
    await _enterPassword(tester, 'qa-reader');
    await _until(tester, () => ready == 2);

    // A new document load must ask again, with no retained password or error.
    await show(plain);
    await _until(tester, () => ready == 3);
    await show(protected);
    await _until(tester, () => find.text('PDFのパスワード').evaluate().isNotEmpty);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.text('パスワードが違います。もう一度入力してください。'), findsNothing);
    await tester.tap(find.text('キャンセル'));
    await _until(
      tester,
      () => find.byType(ViewerStatePanel).evaluate().isNotEmpty,
    );
    expect(ready, 3, reason: 'Cancel must not report content ready');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('再試行'));
    await _enterPassword(tester, 'qa-reader');
    await _until(tester, () => ready == 4);

    // Switching files while the dialog is open must discard the old request.
    await show(plain);
    await _until(tester, () => ready == 5);
    await show(protected);
    await _until(tester, () => find.text('PDFのパスワード').evaluate().isNotEmpty);
    await show(plain);
    await _until(
      tester,
      () => ready == 6 && find.byType(TextField).evaluate().isEmpty,
    );
    expect(find.byType(ViewerStatePanel), findsNothing);

    // Remove only the reader, retaining the Navigator containing its dialog.
    await show(protected);
    await _until(tester, () => find.text('PDFのパスワード').evaluate().isNotEmpty);
    await tester.pumpWidget(
      createProviderApp(
        const SizedBox.shrink(),
        overrides: [
          appDocumentsPathSyncProvider.overrideWith((ref) => directory.path),
        ],
      ),
    );
    await _until(tester, () => find.byType(TextField).evaluate().isEmpty);
    expect(tester.takeException(), isNull);

    // Closing and reopening the same file gets a new loader/UI owner too.
    await show(protected);
    await _enterPassword(tester, 'qa-reader');
    await _until(tester, () => ready == 7);
    await tester.pumpWidget(
      createProviderApp(
        const SizedBox.shrink(),
        overrides: [
          appDocumentsPathSyncProvider.overrideWith((ref) => directory.path),
        ],
      ),
    );
    await tester.pump();
    await show(protected);
    await _until(tester, () => find.text('PDFのパスワード').evaluate().isNotEmpty);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.tap(find.text('キャンセル'));
    await _until(
      tester,
      () => find.byType(ViewerStatePanel).evaluate().isNotEmpty,
    );

    await show(broken);
    await _until(
      tester,
      () => find.byType(ViewerStatePanel).evaluate().isNotEmpty,
    );
    expect(ready, 7);
    await broken.writeAsBytes(pdfFixture());
    await tester.tap(find.text('再試行'));
    await _until(tester, () => ready == 8);
    expect(find.byType(ViewerStatePanel), findsNothing);
    expect(sha256.convert(await plain.readAsBytes()), originalHash);
    expect(sha256.convert(await protected.readAsBytes()), protectedHash);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));
}

// The full preview gesture test exercises the real screen without opening a
// library database or writing viewing history.
class _PreviewViewModel extends MediaViewerViewModel {
  @override
  MediaViewerState build() => const MediaViewerState();
}

class _PreviewCollection extends CollectionNotifier {
  @override
  Future<MediaCollection?> build(String path) async => null;
}

Future<void> _enterPassword(WidgetTester tester, String value) async {
  await _until(tester, () => find.text('PDFのパスワード').evaluate().isNotEmpty);
  // The document's loading spinner continues behind the dialog; do not use
  // pumpAndSettle here. Let outgoing/incoming dialog transitions finish.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.enterText(find.byType(TextField), value);
  await tester.pump();
  await tester.tap(find.text('開く'));
}

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('PDF QA condition timed out');
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}
