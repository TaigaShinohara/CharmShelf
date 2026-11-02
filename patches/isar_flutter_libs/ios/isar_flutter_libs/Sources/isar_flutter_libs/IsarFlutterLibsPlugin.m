#import "IsarFlutterLibsPlugin.h"
#import "binding.h"

@implementation IsarFlutterLibsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
}

- (void)dummyMethodToEnforceBundling {
  // Keep a native symbol reference so the static Isar library is not stripped.
  isar_get_error(0);
}
@end
