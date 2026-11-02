import 'dart:io';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../../feedback/snackbar_service.dart';
import '../../logger/app_logger.dart';
import '../../logger/log_tag.dart';
import '../../services/private_storage_service.dart';
import '../dip_action_log.dart';
import '../dip_feature.dart';

/// キャッシュクリア機能
class CacheClearFeature extends PanelDipFeature {
  @override
  String get id => 'cache_clear';

  @override
  String get title => 'Cache Clear';

  @override
  String? get subtitle => null;

  @override
  IconData get icon => Icons.cleaning_services_outlined;

  @override
  DipFeatureCategory get category => DipFeatureCategory.data;

  @override
  Widget? buildPanel(BuildContext context) {
    return const _CacheClearPanel();
  }
}

class _CacheClearPanel extends ConsumerStatefulWidget {
  const _CacheClearPanel();

  @override
  ConsumerState<_CacheClearPanel> createState() => _CacheClearPanelState();
}

class _CacheClearPanelState extends ConsumerState<_CacheClearPanel> {
  bool _clearing = false;
  Map<String, int> _cacheSizes = {};

  @override
  void initState() {
    super.initState();
    _loadCacheSizes();
  }

  Future<void> _loadCacheSizes() async {
    final sizes = <String, int>{};

    // SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      sizes['SharedPreferences'] = prefs.getKeys().length;
    } catch (_) {
      sizes['SharedPreferences'] = 0;
    }

    // 画像キャッシュ
    const imageCacheLabel = 'ImageCache';
    try {
      final cacheDir = await getTemporaryDirectory();
      sizes[imageCacheLabel] = await _getDirectorySize(cacheDir);
    } catch (_) {
      sizes[imageCacheLabel] = 0;
    }

    // アプリドキュメント
    const appDataLabel = 'AppData';
    try {
      final docDir = await getPrivateStorageDirectory();
      sizes[appDataLabel] = await _getDirectorySize(docDir);
    } catch (_) {
      sizes[appDataLabel] = 0;
    }

    if (mounted) {
      setState(() => _cacheSizes = sizes);
    }
  }

  Future<int> _getDirectorySize(Directory dir) async {
    var size = 0;
    try {
      if (await dir.exists()) {
        await for (final entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            size += await entity.length();
          }
        }
      }
    } catch (e, st) {
      // ディレクトリ走査中のアクセス拒否等のエラーはログを記録し計算できた分を返す
      AppLogger.w(LogTag.app, 'ディレクトリサイズ計算中に例外が発生しました (${dir.path})', e, st);
    }
    return size;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 警告カード
        Card(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.dipCacheClearWarning,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // キャッシュサイズ一覧
        Text(
          l10n.dipCacheClearCurrent,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final entry in _cacheSizes.entries)
                ListTile(
                  title: Text(entry.key),
                  trailing: Text(
                    entry.key == 'SharedPreferences'
                        ? l10n.dipSharedPrefsItems(entry.value)
                        : _formatSize(entry.value),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // クリアボタン
        Text(
          l10n.dipCacheClearOptions,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _ClearButton(
          icon: Icons.storage_outlined,
          title: l10n.dipCacheClearPrefs,
          subtitle: l10n.dipCacheClearPrefsSubtitle,
          onPressed: _clearing ? null : () => _clearSharedPreferences(context),
        ),
        const SizedBox(height: 8),
        _ClearButton(
          icon: Icons.image_outlined,
          title: l10n.dipCacheClearImages,
          subtitle: l10n.dipCacheClearImagesSubtitle,
          onPressed: _clearing ? null : () => _clearImageCache(context),
        ),
        const SizedBox(height: 8),
        _ClearButton(
          icon: Icons.delete_forever,
          title: l10n.dipCacheClearIsar,
          subtitle: l10n.dipCacheClearIsarSubtitle,
          destructive: true,
          onPressed: _clearing ? null : () => _clearIsarDatabase(context),
        ),
        const SizedBox(height: 24),
        // 全削除ボタン
        ElevatedButton.icon(
          onPressed: _clearing ? null : () => _clearAll(context),
          icon: _clearing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_sweep),
          label: Text(l10n.dipCacheClearAll),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
        ),
      ],
    );
  }

  Future<void> _clearSharedPreferences(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _showConfirmDialog(
      context,
      l10n.dipCacheClearPrefsConfirm,
      l10n.dipCacheClearPrefsConfirmMessage,
    );
    if (!confirmed || !context.mounted) return;

    setState(() => _clearing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      DipActionLog.success('SharedPreferencesをクリアしました', tag: 'Cache');
      if (context.mounted) {
        ref
            .read(snackBarServiceProvider)
            .success(context: context, message: l10n.dipCacheClearPrefsDone);
      }
    } catch (e) {
      DipActionLog.error('SharedPreferencesクリア失敗: $e', tag: 'Cache');
    } finally {
      setState(() => _clearing = false);
      _loadCacheSizes();
    }
  }

  Future<void> _clearImageCache(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _showConfirmDialog(
      context,
      l10n.dipCacheClearImagesConfirm,
      l10n.dipCacheClearImagesConfirmMessage,
    );
    if (!confirmed || !context.mounted) return;

    setState(() => _clearing = true);
    try {
      // 一時ディレクトリをクリア
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
      }
      DipActionLog.success('画像キャッシュをクリアしました', tag: 'Cache');
      if (context.mounted) {
        ref
            .read(snackBarServiceProvider)
            .success(context: context, message: l10n.dipCacheClearImagesDone);
      }
    } catch (e) {
      DipActionLog.error('画像キャッシュクリア失敗: $e', tag: 'Cache');
    } finally {
      setState(() => _clearing = false);
      _loadCacheSizes();
    }
  }

  Future<void> _clearIsarDatabase(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _showConfirmDialog(
      context,
      l10n.dipCacheClearIsarConfirm,
      l10n.dipCacheClearIsarConfirmMessage,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    setState(() => _clearing = true);
    try {
      // アプリサポートディレクトリのIsarファイルを削除
      final appDir = await getPrivateStorageDirectory();
      final isarFile = File('${appDir.path}/default.isar');
      if (await isarFile.exists()) {
        await isarFile.delete();
      }
      final isarLockFile = File('${appDir.path}/default.isar.lock');
      if (await isarLockFile.exists()) {
        await isarLockFile.delete();
      }
      DipActionLog.success('Isarデータベースをクリアしました（再起動が必要です）', tag: 'Cache');
      if (context.mounted) {
        ref
            .read(snackBarServiceProvider)
            .success(context: context, message: l10n.dipCacheClearIsarDone);
      }
    } catch (e) {
      DipActionLog.error('Isarクリア失敗: $e', tag: 'Cache');
    } finally {
      setState(() => _clearing = false);
      _loadCacheSizes();
    }
  }

  Future<void> _clearAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _showConfirmDialog(
      context,
      l10n.dipCacheClearAllConfirm,
      l10n.dipCacheClearAllConfirmMessage,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    setState(() => _clearing = true);
    try {
      // SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 画像キャッシュ
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
      }

      // Isarデータベース
      final appDir = await getPrivateStorageDirectory();
      final isarFile = File('${appDir.path}/default.isar');
      if (await isarFile.exists()) {
        await isarFile.delete();
      }

      DipActionLog.success('全てのキャッシュをクリアしました（再起動が必要です）', tag: 'Cache');
      if (context.mounted) {
        ref
            .read(snackBarServiceProvider)
            .success(context: context, message: l10n.dipCacheClearAllDone);
      }
    } catch (e) {
      DipActionLog.error('キャッシュクリア失敗: $e', tag: 'Cache');
    } finally {
      setState(() => _clearing = false);
      _loadCacheSizes();
    }
  }

  Future<bool> _showConfirmDialog(
    BuildContext context,
    String title,
    String message, {
    bool destructive = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          DialogActionRow(
            leading: DialogCloseButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              semanticLabel: l10n.commonCancel,
            ),
            trailing: TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: destructive
                  ? TextButton.styleFrom(
                      foregroundColor: Theme.of(
                        dialogContext,
                      ).colorScheme.error,
                    )
                  : null,
              child: Text(l10n.commonDelete),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: destructive ? theme.colorScheme.error : null,
        ),
        title: Text(
          title,
          style: destructive ? TextStyle(color: theme.colorScheme.error) : null,
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onPressed,
      ),
    );
  }
}
