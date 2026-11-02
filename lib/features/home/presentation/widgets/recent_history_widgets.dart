import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderBase;
import '../../../../gen_l10n/app_localizations.dart';

/// Shared presentation for both kinds of home history.
class RecentHistorySection<T> extends ConsumerWidget {
  const RecentHistorySection({
    super.key,
    required this.title,
    required this.icon,
    required this.provider,
    required this.itemBuilder,
    this.listProvider,
    this.fullPage = false,
  });
  final String title;
  final Widget icon;
  final ProviderBase<AsyncValue<List<T>>> provider;
  final ProviderBase<AsyncValue<List<T>>>? listProvider;
  final Widget Function(BuildContext, T) itemBuilder;
  final bool fullPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provider);
    final l10n = AppLocalizations.of(context)!;
    final items = state.value;
    if (!fullPage &&
        !state.isLoading &&
        !state.hasError &&
        items != null &&
        items.isEmpty) {
      return const SizedBox.shrink();
    }
    final body = state.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: false,
      data: (items) => items.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.homeRecentHistoryEmpty),
            )
          : RecentHistoryGrid(
              children: [
                for (final item in items.take(fullPage ? 20 : 4))
                  itemBuilder(context, item),
              ],
            ),
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(l10n.commonErrorOccurred),
            TextButton.icon(
              onPressed: () => ref.invalidate(provider),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
    if (fullPage) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.homeRecentHistoryLimit,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                body,
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  IconTheme(
                    data: IconThemeData(
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: icon,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if ((!state.isLoading || state.isRefreshing) &&
                      !state.hasError &&
                      (items?.length ?? 0) > 4)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(
                            name: '/home/recent-history',
                          ),
                          builder: (_) => RecentHistorySection<T>(
                            title: title,
                            icon: icon,
                            provider: listProvider ?? provider,
                            itemBuilder: itemBuilder,
                            fullPage: true,
                          ),
                        ),
                      ),
                      child: Text(l10n.homeSeeMore),
                    ),
                ],
              ),
            ),
          ),
          body,
        ],
      ),
    );
  }
}

class RecentHistoryGrid extends StatelessWidget {
  const RecentHistoryGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final columns =
            ((constraints.maxWidth + 8) / ((scale >= 1.6 ? 200 : 144) + 8))
                .floor()
                .clamp(1, children.length.clamp(1, 4));
        final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
        // Wide cards use a compact row; narrow cards keep the image above the
        // details. Both reserve more text space for accessibility settings.
        final height = width >= 300
            ? (96 * scale + 32).clamp(128.0, double.infinity)
            : width * .75 + 32 + 96 * scale;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final child in children)
              SizedBox(width: width, height: height, child: child),
          ],
        );
      },
    ),
  );
}

class RecentHistoryCard extends StatelessWidget {
  const RecentHistoryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.onTap,
    required this.onActions,
    this.metadata = '',
    this.tapKey,
    this.badges = const [],
  });
  final String title;
  final String subtitle;
  final String metadata;
  final Widget preview;
  final VoidCallback? onTap;
  final VoidCallback? onActions;
  final Key? tapKey;
  final List<Widget> badges;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              enabled: onTap != null,
              label: [
                title,
                subtitle,
                metadata,
              ].where((part) => part.isNotEmpty).join(', '),
              child: InkWell(
                key: tapKey,
                onTap: onTap,
                onLongPress: onActions,
                child: ExcludeSemantics(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final details = _details(theme);
                      final image = Stack(
                        fit: StackFit.expand,
                        children: [
                          preview,
                          if (badges.isNotEmpty)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Row(children: badges),
                            ),
                        ],
                      );
                      if (constraints.maxWidth >= 300) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 112, child: image),
                            Expanded(child: details),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AspectRatio(aspectRatio: 4 / 3, child: image),
                          Expanded(child: details),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: IconButton(
              onPressed: onActions,
              tooltip: AppLocalizations.of(context)!.libraryMoreActions,
              icon: const Icon(Icons.more_vert),
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge,
        ),
      ),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 48, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (metadata.isNotEmpty)
              Text(
                metadata,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
