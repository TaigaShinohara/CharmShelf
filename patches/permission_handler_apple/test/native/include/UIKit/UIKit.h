#import <Foundation/Foundation.h>

// Test adapter only. No application or operating-system permission API is used.
@interface UIApplication : NSObject
+ (instancetype)sharedApplication;
- (void)registerForRemoteNotifications;
@end
