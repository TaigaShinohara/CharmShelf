import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/tip_purchase_service.dart';
import '../domain/tip_item.dart';
import 'providers/tip_purchase_provider.dart';

class TipPage extends ConsumerWidget {
  const TipPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final purchaseState = ref.watch(tipPurchaseProvider);

    ref.listen(tipPurchaseProvider, (previous, next) {
      final previousValue = previous?.value;
      final nextValue = next.value;
      if (previousValue == null ||
          nextValue == null ||
          previousValue.event == nextValue.event) {
        return;
      }

      final message = switch (nextValue.event) {
        TipPurchaseUpdateType.completed => l10n.tipPurchaseThankYou,
        TipPurchaseUpdateType.canceled => l10n.tipPurchaseCanceled,
        TipPurchaseUpdateType.failed => l10n.tipPurchaseFailed,
        TipPurchaseUpdateType.unconfirmed => l10n.tipPurchaseUnconfirmed,
        TipPurchaseUpdateType.pending => null,
      };
      if (message != null) {
        AppSnackBarMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return Scaffold(
      appBar: PremiumAppBar(titleText: l10n.tipPageTitle),
      body: SafeArea(
        top: false,
        child: purchaseState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _LoadError(
            message: l10n.tipStoreUnavailable,
            retryLabel: l10n.commonRetry,
            onRetry: () => ref.read(tipPurchaseProvider.notifier).retry(),
          ),
          data: (state) => _TipContent(
            state: state,
            onPurchase: (item) => _confirmPurchase(context, ref, item, state),
            onRetry: () => ref.read(tipPurchaseProvider.notifier).retry(),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmPurchase(
    BuildContext context,
    WidgetRef ref,
    TipItem item,
    TipPurchaseState state,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final price = state.catalog.prices[item];
    if (price == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.tipConfirmTitle),
        content: Text(l10n.tipConfirmMessage(_itemName(l10n, item), price)),
        actions: [
          DialogActionRow(
            leading: DialogCloseButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              semanticLabel: l10n.commonCancel,
            ),
            trailing: FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.tipConfirmPurchase),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(tipPurchaseProvider.notifier).purchase(item);
    }
  }
}

class _TipContent extends StatelessWidget {
  const _TipContent({
    required this.state,
    required this.onPurchase,
    required this.onRetry,
  });

  final TipPurchaseState state;
  final ValueChanged<TipItem> onPurchase;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final catalog = state.catalog;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        Icon(
          Icons.favorite_rounded,
          size: 52,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.tipPageHeading,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.tipPageDescription,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (!catalog.isStoreAvailable ||
            catalog.hasLoadError ||
            catalog.prices.length != TipItem.values.length)
          _LoadError(
            message: l10n.tipStoreUnavailable,
            retryLabel: l10n.commonRetry,
            onRetry: onRetry,
          ),
        if (state.event == TipPurchaseUpdateType.failed)
          _LoadError(
            message: l10n.tipPurchaseFailed,
            retryLabel: l10n.commonRetry,
            onRetry: onRetry,
          ),
        if (state.event == TipPurchaseUpdateType.unconfirmed)
          Padding(
            padding: AppSpacing.edgeInsetsLg,
            child: Text(l10n.tipPurchaseUnconfirmed),
          ),
        for (final item in TipItem.values) ...[
          _TipCard(
            item: item,
            price: catalog.prices[item] ?? l10n.tipPriceUnavailable,
            enabled:
                catalog.isStoreAvailable &&
                catalog.prices.containsKey(item) &&
                state.pendingItem == null,
            isPending: state.pendingItem == item,
            onPressed: () => onPurchase(item),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.tipPurchaseNotice,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.item,
    required this.price,
    required this.enabled,
    required this.isPending,
    required this.onPressed,
  });

  final TipItem item;
  final String price;
  final bool enabled;
  final bool isPending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: AppSpacing.edgeInsetsLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.65),
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      _itemEmoji(item),
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _itemName(l10n, item),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: enabled ? onPressed : null,
              child: isPending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(price, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.edgeInsetsLg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

String _itemName(AppLocalizations l10n, TipItem item) => switch (item) {
  TipItem.juice => l10n.tipJuice,
  TipItem.coffee => l10n.tipCoffee,
  TipItem.ramen => l10n.tipRamen,
};

String _itemEmoji(TipItem item) => switch (item) {
  TipItem.juice => '🧃',
  TipItem.coffee => '☕',
  TipItem.ramen => '🍜',
};
