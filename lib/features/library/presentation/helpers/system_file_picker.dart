import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_storage/shared_storage.dart' as saf;

import '../../../../core/logger/app_logger.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../../core/logger/log_tag.dart';
import '../../../../core/providers/shared_preferences_provider.dart';
import '../../domain/models/selected_document.dart';
import 'import_picker_notification_helper.dart';

const systemFilePickerGrantReleasesKey =
    AppPreferences.importPickerGrantReleasesKey;

final systemFilePickerIsAndroidProvider = Provider<bool>(
  (ref) => Platform.isAndroid,
);

final systemFilePickerProvider = Provider<SystemFilePicker>(
  (ref) => SystemFilePicker(
    rememberUnreleasedGrants: (grants) async => _rememberGrants(
      await ref.read(sharedPreferencesProvider.future),
      grants,
    ),
  ),
);

Future<void> _rememberGrants(
  SharedPreferences preferences,
  Set<Uri> grants,
) async {
  if (grants.isEmpty) return;
  final pending =
      (preferences.getStringList(systemFilePickerGrantReleasesKey) ?? [])
          .toSet()
        ..addAll(grants.map((uri) => '$uri'));
  if (!await preferences.setStringList(
    systemFilePickerGrantReleasesKey,
    pending.toList(),
  )) {
    throw const SystemFilePickerException();
  }
}

/// A failed picker or unreadable selection, distinct from cancellation (null).
class SystemFilePickerException implements Exception {
  const SystemFilePickerException();
}

typedef DocumentPicker =
    Future<List<Uri>?> Function({
      Uri? initialUri,
      required bool grantWritePermission,
      required bool persistablePermission,
      required String mimeType,
      required bool multiple,
    });
typedef FolderPicker =
    Future<Uri?> Function({
      required bool grantWritePermission,
      required bool persistablePermission,
      Uri? initialUri,
    });
typedef SystemPickerRunner =
    Future<T?> Function<T>({required Future<T?> Function() pick});

/// All three entry points use Android's document picker with read-only access.
class SystemFilePicker {
  SystemFilePicker({
    DocumentPicker? documents,
    FolderPicker? folder,
    Future<List<saf.UriPermission>?> Function()? permissions,
    Future<saf.DocumentFile?> Function(Uri)? metadata,
    Future<bool?> Function(Uri)? canRead,
    Future<void> Function(Uri)? release,
    Future<void> Function(Set<Uri>)? rememberUnreleasedGrants,
    SystemPickerRunner? runPicker,
  }) : _documents = documents ?? saf.openDocument,
       _folder = folder ?? saf.openDocumentTree,
       _permissions = permissions ?? saf.persistedUriPermissions,
       _metadata = metadata ?? saf.DocumentFile.fromTreeUri,
       _canRead = canRead ?? saf.canRead,
       _release = release ?? saf.releasePersistableUriPermission,
       _rememberUnreleasedGrants =
           rememberUnreleasedGrants ??
           ((grants) async =>
               _rememberGrants(await SharedPreferences.getInstance(), grants)),
       _runPicker = runPicker ?? runImportPicker;

  final DocumentPicker _documents;
  final FolderPicker _folder;
  final Future<List<saf.UriPermission>?> Function() _permissions;
  final Future<saf.DocumentFile?> Function(Uri) _metadata;
  final Future<bool?> Function(Uri) _canRead;
  final Future<void> Function(Uri) _release;
  final Future<void> Function(Set<Uri>) _rememberUnreleasedGrants;
  final SystemPickerRunner _runPicker;

  Future<SelectedDocument?> openFile() async {
    final documents = await _run(
      () => _pickDocuments(multiple: false, persist: false),
      releaseDocuments,
    );
    return documents?.single;
  }

  Future<List<SelectedDocument>?> pickFiles() => _run(
    () => _pickDocuments(multiple: true, persist: true),
    releaseDocuments,
  );

  Future<PickedFolder?> pickFolder() => _run(_pickFolder, releaseFolder);

  /// A notification return may finish before the native selection settles.
  /// Late results are discarded and only their newly acquired grants released.
  Future<T?> _run<T>(
    Future<T?> Function() pick,
    Future<void> Function(T) release,
  ) async {
    var finished = false;
    T? pending;
    try {
      final result = await _runPicker<T>(
        pick: () async {
          final value = await pick();
          pending = value;
          if (finished && value != null) {
            pending = null;
            await release(value);
            return null;
          }
          return value;
        },
      );
      finished = true;
      if (result == null && pending != null) {
        final abandoned = pending as T;
        pending = null;
        await release(abandoned);
      }
      return result;
    } catch (error, stack) {
      finished = true;
      if (pending != null) {
        final abandoned = pending as T;
        pending = null;
        try {
          await release(abandoned);
        } catch (cleanupError, cleanupStack) {
          AppLogger.e(
            LogTag.storage,
            '標準ファイル選択失敗後のアクセス解放を再試行する必要があります',
            cleanupError,
            cleanupStack,
          );
        }
      }
      Error.throwWithStackTrace(error, stack);
    } finally {
      finished = true;
    }
  }

  Future<Set<Uri>> _persisted() async {
    final permissions = await _permissions();
    if (permissions == null) throw const SystemFilePickerException();
    return permissions.map((permission) => permission.uri).toSet();
  }

  Future<Set<Uri>> _owned(Set<Uri> before, Iterable<Uri> selected) async {
    final after = await _persisted();
    return selected
        .where((uri) => !before.contains(uri) && after.contains(uri))
        .toSet();
  }

  Future<List<SelectedDocument>?> _pickDocuments({
    required bool multiple,
    required bool persist,
  }) async {
    final before = persist ? await _persisted() : <Uri>{};
    var owned = <Uri>{};
    var selected = <Uri>[];
    try {
      selected =
          (await _documents(
            grantWritePermission: false,
            persistablePermission: persist,
            mimeType: '*/*',
            multiple: multiple,
          ))?.toSet().toList() ??
          [];
      if (selected.isEmpty) return null;
      if (persist) owned = await _owned(before, selected);
      if (!multiple && selected.length != 1) {
        throw const SystemFilePickerException();
      }
      final documents = <SelectedDocument>[];
      for (final uri in selected) {
        _validateUri(uri);
        final metadata = await _metadata(uri);
        final name = metadata?.name;
        if (metadata == null ||
            metadata.isDirectory == true ||
            name == null ||
            name.trim().isEmpty ||
            await _canRead(uri) != true) {
          throw const SystemFilePickerException();
        }
        documents.add(
          SelectedDocument(
            uri: uri,
            name: name,
            size: metadata.size,
            mimeType: metadata.type,
            ownsGrant: owned.contains(uri),
          ),
        );
      }
      return documents;
    } catch (error, stack) {
      if (persist) await _cleanupFailure(error, before, selected, owned);
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<PickedFolder?> _pickFolder() async {
    final before = await _persisted();
    Uri? selected;
    var owned = <Uri>{};
    try {
      selected = await _folder(
        grantWritePermission: false,
        persistablePermission: true,
      );
      if (selected == null) return null;
      owned = await _owned(before, [selected]);
      _validateUri(selected);
      final metadata = await _metadata(selected);
      if (metadata?.isDirectory != true || await _canRead(selected) != true) {
        throw const SystemFilePickerException();
      }
      return PickedFolder(uri: selected, ownsGrant: owned.contains(selected));
    } catch (error, stack) {
      await _cleanupFailure(
        error,
        before,
        selected == null ? const <Uri>[] : <Uri>[selected],
        owned,
      );
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> _cleanupFailure(
    Object error,
    Set<Uri> before,
    List<Uri> selected,
    Set<Uri> owned,
  ) async {
    final toRelease = {...owned};
    if (error is PlatformException && error.details is Map) {
      final grants = (error.details as Map)['unreleasedUriGrants'];
      if (grants is List) {
        for (final grant in grants) {
          if (grant is! Map ||
              grant['uri'] is! String ||
              grant['flags'] is! int) {
            continue;
          }
          final uri = Uri.tryParse(grant['uri'] as String);
          if (uri != null &&
              uri.scheme == 'content' &&
              uri.authority.isNotEmpty &&
              !before.contains(uri) &&
              ((grant['flags'] as int) & 1) != 0) {
            toRelease.add(uri);
          }
        }
      }
    }
    try {
      if (selected.isNotEmpty && owned.isEmpty) {
        try {
          toRelease.addAll(await _owned(before, selected));
        } catch (_) {
          // A failed ownership query must never revoke previously held access.
          await _rememberUnreleasedGrants(
            selected.where((uri) => !before.contains(uri)).toSet(),
          );
        }
      }
      await _releaseAll(toRelease);
    } catch (cleanupError, cleanupStack) {
      // Retain the picker/metadata error as the primary failure.
      AppLogger.e(
        LogTag.storage,
        '標準ファイル選択のアクセス解放を再試行する必要があります',
        cleanupError,
        cleanupStack,
      );
    }
  }

  void _validateUri(Uri uri) {
    if (uri.scheme != 'content' || uri.authority.isEmpty) {
      throw const SystemFilePickerException();
    }
  }

  Future<void> releaseDocuments(List<SelectedDocument> documents) =>
      _releaseAll(
        documents
            .where((document) => document.ownsGrant)
            .map((document) => document.uri),
      );

  Future<void> releaseFolder(PickedFolder folder) =>
      _releaseAll(folder.ownsGrant ? [folder.uri] : []);

  Future<void> _releaseAll(Iterable<Uri> uris) async {
    Object? failure;
    StackTrace? failureStack;
    final unreleased = <Uri>{};
    for (final uri in uris.toSet()) {
      try {
        await _release(uri);
      } catch (error, stack) {
        failure ??= error;
        failureStack ??= stack;
        unreleased.add(uri);
      }
    }
    if (failure != null) {
      await _rememberUnreleasedGrants(unreleased);
      Error.throwWithStackTrace(failure, failureStack!);
    }
  }
}
