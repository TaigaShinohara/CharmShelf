// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$rootRoute, $passcodeRoute];

RouteBase get $rootRoute => GoRouteData.$route(
  path: '/',
  hasOverriddenOnExit: false,
  factory: $RootRoute._fromState,
  routes: [
    GoRouteData.$route(
      path: 'viewer/:id',
      hasOverriddenOnExit: false,
      factory: $MediaViewerRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'tags',
      hasOverriddenOnExit: false,
      factory: $TagManagementRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'settings',
      hasOverriddenOnExit: false,
      factory: $SettingsRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'privacy',
      hasOverriddenOnExit: false,
      factory: $PrivacySettingsRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'info',
      hasOverriddenOnExit: false,
      factory: $InfoRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'archive',
      hasOverriddenOnExit: false,
      factory: $ArchiveRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'trash',
      hasOverriddenOnExit: false,
      factory: $TrashRoute._fromState,
    ),
  ],
);

mixin $RootRoute on GoRouteData {
  static RootRoute _fromState(GoRouterState state) => const RootRoute();

  @override
  String get location => GoRouteData.$location('/');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $MediaViewerRoute on GoRouteData {
  static MediaViewerRoute _fromState(GoRouterState state) => MediaViewerRoute(
    id: int.parse(state.pathParameters['id']!),
    $extra: state.extra as ViewerRouteArgs?,
  );

  MediaViewerRoute get _self => this as MediaViewerRoute;

  @override
  String get location => GoRouteData.$location(
    '/viewer/${Uri.encodeComponent(_self.id.toString())}',
  );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

mixin $TagManagementRoute on GoRouteData {
  static TagManagementRoute _fromState(GoRouterState state) =>
      const TagManagementRoute();

  @override
  String get location => GoRouteData.$location('/tags');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $SettingsRoute on GoRouteData {
  static SettingsRoute _fromState(GoRouterState state) => const SettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $PrivacySettingsRoute on GoRouteData {
  static PrivacySettingsRoute _fromState(GoRouterState state) =>
      const PrivacySettingsRoute();

  @override
  String get location => GoRouteData.$location('/privacy');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $InfoRoute on GoRouteData {
  static InfoRoute _fromState(GoRouterState state) => InfoRoute(
    title: state.uri.queryParameters['title']!,
    content: state.uri.queryParameters['content']!,
  );

  InfoRoute get _self => this as InfoRoute;

  @override
  String get location => GoRouteData.$location(
    '/info',
    queryParams: {'title': _self.title, 'content': _self.content},
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ArchiveRoute on GoRouteData {
  static ArchiveRoute _fromState(GoRouterState state) => const ArchiveRoute();

  @override
  String get location => GoRouteData.$location('/archive');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $TrashRoute on GoRouteData {
  static TrashRoute _fromState(GoRouterState state) => const TrashRoute();

  @override
  String get location => GoRouteData.$location('/trash');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $passcodeRoute => GoRouteData.$route(
  path: '/passcode',
  hasOverriddenOnExit: false,
  factory: $PasscodeRoute._fromState,
);

mixin $PasscodeRoute on GoRouteData {
  static PasscodeRoute _fromState(GoRouterState state) => PasscodeRoute(
    from: state.uri.queryParameters['from'],
    $extra: state.extra as PasscodeRouteArgs?,
  );

  PasscodeRoute get _self => this as PasscodeRoute;

  @override
  String get location => GoRouteData.$location(
    '/passcode',
    queryParams: {if (_self.from != null) 'from': _self.from},
  );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ルーター設定（go_router）

@ProviderFor(router)
final routerProvider = RouterProvider._();

/// ルーター設定（go_router）

final class RouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// ルーター設定（go_router）
  RouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routerHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return router(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$routerHash() => r'2e3472af9d7c5cb4477cbd9cffe1f4b8e816a850';
