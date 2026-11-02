#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

typedef NS_ENUM(NSInteger, UNAuthorizationStatus) {
  UNAuthorizationStatusNotDetermined = 0,
  UNAuthorizationStatusDenied = 1,
  UNAuthorizationStatusAuthorized = 2,
  UNAuthorizationStatusProvisional = 3,
  UNAuthorizationStatusEphemeral = 4,
};

typedef NS_OPTIONS(NSUInteger, UNAuthorizationOptions) {
  UNAuthorizationOptionBadge = 1 << 0,
  UNAuthorizationOptionSound = 1 << 1,
  UNAuthorizationOptionAlert = 1 << 2,
};

@interface UNNotificationSettings : NSObject
@property(nonatomic) UNAuthorizationStatus authorizationStatus;
@end

@interface UNUserNotificationCenter : NSObject
+ (instancetype)currentNotificationCenter;
- (void)getNotificationSettingsWithCompletionHandler:
    (void (^)(UNNotificationSettings *settings))completionHandler;
- (void)requestAuthorizationWithOptions:(UNAuthorizationOptions)options
                     completionHandler:(void (^)(BOOL granted, NSError *error))completionHandler;
@end
