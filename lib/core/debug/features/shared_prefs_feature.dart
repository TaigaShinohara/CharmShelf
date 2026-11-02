import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../dip_action_log.dart';
import '../dip_feature.dart';

/// SharedPreferences閲覧・編集機能
class SharedPrefsFeature extends PanelDipFeature {
  @override
  String get id => 'shared_prefs';

  @override
  String get title => 'SharedPreferences';

  @override
  String? get subtitle => null;

  String subtitleText(BuildContext context) =>
      AppLocalizations.of(context)!.dipSharedPrefsSubtitle;

  @override
  IconData get icon => Icons.save_outlined;

  @override
  DipFeatureCategory get category => DipFeatureCategory.data;

  @override
  Widget? buildPanel(BuildContext context) {
    return const _SharedPrefsPanel();
  }
}

class _SharedPrefsPanel extends StatefulWidget {
  const _SharedPrefsPanel();

  @override
  State<_SharedPrefsPanel> createState() => _SharedPrefsPanelState();
}

class _SharedPrefsPanelState extends State<_SharedPrefsPanel> {
  SharedPreferences? _prefs;
  List<_PrefEntry> _entries = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList()..sort();

    final entries = <_PrefEntry>[];
    for (final key in keys) {
      final value = prefs.get(key);
      entries.add(_PrefEntry(key: key, value: value, type: _getType(value)));
    }

    if (mounted) {
      setState(() {
        _prefs = prefs;
        _entries = entries;
        _loading = false;
      });
    }
  }

  String _getType(dynamic value) {
    if (value is String) return 'String';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is bool) return 'bool';
    if (value is List<String>) return 'List<String>';
    return 'Unknown';
  }

  List<_PrefEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return _entries;
    final query = _searchQuery.toLowerCase();
    return _entries.where((e) {
      return e.key.toLowerCase().contains(query) ||
          e.value.toString().toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final entries = _filteredEntries;

    return Column(
      children: [
        // 検索バーとアクション
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: l10n.commonSearch,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    l10n.dipSharedPrefsItems(entries.length),
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _loadPrefs,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(l10n.commonUpdate),
                  ),
                  TextButton.icon(
                    onPressed: () => _addNew(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.commonAdd),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // エントリリスト
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? l10n.dipSharedPrefsNoData
                        : l10n.dipSharedPrefsNoMatch,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _PrefTile(
                      entry: entry,
                      onEdit: () => _edit(context, entry),
                      onDelete: () => _delete(context, entry),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _addNew(BuildContext context) async {
    final result = await showDialog<_PrefEntry>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => const _AddEditDialog(),
    );

    if (result != null && _prefs != null) {
      await _saveEntry(result);
      await _loadPrefs();
      DipActionLog.info('SharedPrefs追加: ${result.key}', tag: 'Prefs');
    }
  }

  Future<void> _edit(BuildContext context, _PrefEntry entry) async {
    final result = await showDialog<_PrefEntry>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => _AddEditDialog(entry: entry),
    );

    if (result != null && _prefs != null) {
      await _saveEntry(result);
      await _loadPrefs();
      DipActionLog.info('SharedPrefs編集: ${result.key}', tag: 'Prefs');
    }
  }

  Future<void> _saveEntry(_PrefEntry entry) async {
    if (_prefs == null) return;

    switch (entry.type) {
      case 'String':
        await _prefs!.setString(entry.key, entry.value as String);
      case 'int':
        await _prefs!.setInt(entry.key, entry.value as int);
      case 'double':
        await _prefs!.setDouble(entry.key, entry.value as double);
      case 'bool':
        await _prefs!.setBool(entry.key, entry.value as bool);
      case 'List<String>':
        await _prefs!.setStringList(entry.key, entry.value as List<String>);
    }
  }

  Future<void> _delete(BuildContext context, _PrefEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.dipSharedPrefsDeleteConfirm),
        content: Text(l10n.dipSharedPrefsDeleteMessage(entry.key)),
        actions: [
          DialogActionRow(
            leading: DialogCloseButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              semanticLabel: l10n.commonCancel,
            ),
            trailing: TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.commonDelete),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && _prefs != null) {
      await _prefs!.remove(entry.key);
      await _loadPrefs();
      DipActionLog.info('SharedPrefs削除: ${entry.key}', tag: 'Prefs');
    }
  }
}

class _PrefEntry {
  _PrefEntry({required this.key, required this.value, required this.type});

  final String key;
  final dynamic value;
  final String type;
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final _PrefEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        entry.key,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.value.toString(),
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            entry.type,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: onEdit),
          IconButton(
            icon: Icon(Icons.delete, size: 20, color: theme.colorScheme.error),
            onPressed: onDelete,
          ),
        ],
      ),
      onTap: onEdit,
    );
  }
}

class _AddEditDialog extends StatefulWidget {
  const _AddEditDialog({this.entry});

  final _PrefEntry? entry;

  @override
  State<_AddEditDialog> createState() => _AddEditDialogState();
}

class _AddEditDialogState extends State<_AddEditDialog> {
  late TextEditingController _keyController;
  late TextEditingController _valueController;
  String _type = 'String';
  bool _boolValue = false;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.entry?.key ?? '');
    _valueController = TextEditingController(
      text: widget.entry?.value?.toString() ?? '',
    );
    if (widget.entry != null) {
      _type = widget.entry!.type;
      if (_type == 'bool') {
        _boolValue = widget.entry!.value as bool;
      }
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.entry != null;

    return AlertDialog(
      actionsAlignment: MainAxisAlignment.spaceBetween,
      title: Text(
        isEdit ? l10n.dipSharedPrefsEditTitle : l10n.dipSharedPrefsAddTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _keyController,
              decoration: InputDecoration(
                labelText: l10n.dipSharedPrefsKey,
                border: const OutlineInputBorder(),
              ),
              enabled: !isEdit,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: l10n.dipSharedPrefsType,
                border: const OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'String', child: Text('String')),
                DropdownMenuItem(value: 'int', child: Text('int')),
                DropdownMenuItem(value: 'double', child: Text('double')),
                DropdownMenuItem(value: 'bool', child: Text('bool')),
              ],
              onChanged: (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: 16),
            if (_type == 'bool')
              SwitchListTile(
                title: Text(l10n.dipSharedPrefsValue),
                value: _boolValue,
                onChanged: (value) => setState(() => _boolValue = value),
              )
            else
              TextField(
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: l10n.dipSharedPrefsValue,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: _type == 'int' || _type == 'double'
                    ? TextInputType.number
                    : TextInputType.text,
                maxLines: _type == 'String' ? 3 : 1,
              ),
          ],
        ),
      ),
      actions: [
        DialogActionRow(
          leading: DialogCloseButton(
            onPressed: () => Navigator.pop(context),
            semanticLabel: l10n.commonCancel,
          ),
          trailing: TextButton(
            onPressed: () {
              final key = _keyController.text.trim();
              if (key.isEmpty) return;

              dynamic value;
              switch (_type) {
                case 'String':
                  value = _valueController.text;
                case 'int':
                  value = int.tryParse(_valueController.text) ?? 0;
                case 'double':
                  value = double.tryParse(_valueController.text) ?? 0.0;
                case 'bool':
                  value = _boolValue;
              }

              Navigator.pop(
                context,
                _PrefEntry(key: key, value: value, type: _type),
              );
            },
            child: Text(l10n.commonSave),
          ),
        ),
      ],
    );
  }
}
