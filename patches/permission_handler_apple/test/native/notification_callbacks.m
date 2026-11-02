#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#include <stdio.h>
#include <stdlib.h>

#import "NotificationPermissionStrategy.h"

// Compile the production strategy unchanged. The adapters answer on the main
// queue, reproducing the callback scheduling that deadlocked the old request.
static UNAuthorizationStatus settingsStatus;
static BOOL authorizationGranted;
static BOOL authorizationError;
static NSUInteger authorizationCalls;
static NSUInteger registrationCalls;
static NSUInteger completedCases;

static void Check(BOOL condition, const char *message) {
  if (!condition) {
    fprintf(stderr, "FAIL: %s\n", message);
    exit(1);
  }
}

@implementation UNNotificationSettings
@end

@implementation UIApplication
+ (instancetype)sharedApplication {
  static UIApplication *application;
  if (!application) application = [UIApplication new];
  return application;
}
- (void)registerForRemoteNotifications {
  Check([NSThread isMainThread], "remote registration must stay on the main thread");
  registrationCalls++;
}
@end

@implementation UNUserNotificationCenter
+ (instancetype)currentNotificationCenter {
  static UNUserNotificationCenter *center;
  if (!center) center = [UNUserNotificationCenter new];
  return center;
}
- (void)getNotificationSettingsWithCompletionHandler:
    (void (^)(UNNotificationSettings *settings))completionHandler {
  UNNotificationSettings *settings = [UNNotificationSettings new];
  settings.authorizationStatus = settingsStatus;
  dispatch_async(dispatch_get_main_queue(), ^{ completionHandler(settings); });
}
- (void)requestAuthorizationWithOptions:(UNAuthorizationOptions)options
                     completionHandler:(void (^)(BOOL granted, NSError *error))completionHandler {
  Check([NSThread isMainThread], "authorization request must stay on the main thread");
  Check(options == (UNAuthorizationOptionBadge | UNAuthorizationOptionSound |
                    UNAuthorizationOptionAlert), "authorization options changed");
  authorizationCalls++;
  BOOL granted = authorizationGranted;
  NSError *error = authorizationError ? [NSError errorWithDomain:@"synthetic" code:1 userInfo:nil] : nil;
  dispatch_async(dispatch_get_main_queue(), ^{ completionHandler(granted, error); });
}
@end

typedef struct {
  UNAuthorizationStatus status;
  PermissionStatus expected;
} StatusCase;

static const StatusCase statusCases[] = {
  {UNAuthorizationStatusNotDetermined, PermissionStatusDenied},
  {UNAuthorizationStatusDenied, PermissionStatusPermanentlyDenied},
  {UNAuthorizationStatusAuthorized, PermissionStatusGranted},
  {UNAuthorizationStatusProvisional, PermissionStatusProvisional},
  {UNAuthorizationStatusEphemeral, PermissionStatusGranted},
};

typedef struct {
  UNAuthorizationStatus status;
  BOOL granted;
  BOOL error;
  PermissionStatus expected;
  NSUInteger requests;
  NSUInteger registrations;
} RequestCase;

static const RequestCase requestCases[] = {
  {UNAuthorizationStatusNotDetermined, YES, NO, PermissionStatusGranted, 1, 1},
  {UNAuthorizationStatusDenied, YES, NO, PermissionStatusPermanentlyDenied, 0, 0},
  {UNAuthorizationStatusAuthorized, YES, NO, PermissionStatusGranted, 0, 0},
  {UNAuthorizationStatusProvisional, YES, NO, PermissionStatusGranted, 1, 1},
  {UNAuthorizationStatusEphemeral, YES, NO, PermissionStatusGranted, 0, 0},
  {UNAuthorizationStatusNotDetermined, NO, NO, PermissionStatusPermanentlyDenied, 1, 0},
  {UNAuthorizationStatusNotDetermined, YES, YES, PermissionStatusPermanentlyDenied, 1, 0},
};

static void RunRequestCase(NSUInteger index) {
  if (index == sizeof(requestCases) / sizeof(requestCases[0])) {
    printf("PASS: %lu synthetic notification callback cases\n", (unsigned long)completedCases);
    exit(0);
  }
  RequestCase test = requestCases[index];
  settingsStatus = test.status;
  authorizationGranted = test.granted;
  authorizationError = test.error;
  authorizationCalls = registrationCalls = 0;
  __block BOOL returned = NO;
  __block NSUInteger callbacks = 0;
  NotificationPermissionStrategy *strategy = [NotificationPermissionStrategy new];
  [strategy requestPermission:PermissionGroupNotification completionHandler:^(PermissionStatus status) {
    Check(returned, "request blocked waiting for notification settings");
    Check([NSThread isMainThread], "request completion left the main queue");
    Check(++callbacks == 1, "request completed more than once");
    Check(status == test.expected, "request status mapping changed");
    Check(authorizationCalls == test.requests, "unexpected authorization request count");
    Check(registrationCalls == test.registrations, "unexpected remote registration count");
    completedCases++;
    dispatch_async(dispatch_get_main_queue(), ^{ RunRequestCase(index + 1); });
  } errorHandler:^(NSString *code, NSString *description) {
    Check(NO, "notification request unexpectedly used the error callback");
  }];
  returned = YES;
}

static void RunStatusCase(NSUInteger index) {
  if (index == sizeof(statusCases) / sizeof(statusCases[0])) {
    RunRequestCase(0);
    return;
  }
  StatusCase test = statusCases[index];
  settingsStatus = test.status;
  authorizationCalls = registrationCalls = 0;
  __block BOOL returned = NO;
  __block NSUInteger callbacks = 0;
  NotificationPermissionStrategy *strategy = [NotificationPermissionStrategy new];
  [strategy checkPermissionStatus:PermissionGroupNotification completionHandler:^(PermissionStatus status) {
    Check(returned, "status blocked waiting for notification settings");
    Check([NSThread isMainThread], "synthetic main-queue status completion left the main queue");
    Check(++callbacks == 1, "status completed more than once");
    Check(status == test.expected, "status mapping changed");
    Check(authorizationCalls == 0 && registrationCalls == 0, "status check requested permission");
    completedCases++;
    dispatch_async(dispatch_get_main_queue(), ^{ RunStatusCase(index + 1); });
  }];
  returned = YES;
}

int main(void) {
  @autoreleasepool {
    Check([NSThread isMainThread], "test must start on the main thread");
    RunStatusCase(0);
    CFRunLoopRun();
  }
  return 1;
}
