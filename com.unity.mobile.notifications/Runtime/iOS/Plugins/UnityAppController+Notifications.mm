//
//  UnityAppController+Notifications.m
//  iOS.notifications
//

#if TARGET_OS_IOS

#import <objc/runtime.h>

#import "UnityNotificationManager.h"
#import "UnityAppController+Notifications.h"

@implementation UnityNotificationLifeCycleManager

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [UnityNotificationLifeCycleManager sharedInstance];
    });
}

+ (instancetype)sharedInstance;
{
    static UnityNotificationLifeCycleManager *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[UnityNotificationLifeCycleManager alloc] init];
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

        [nc addObserverForName: UIApplicationDidBecomeActiveNotification
         object: nil
         queue: [NSOperationQueue mainQueue]
         usingBlock:^(NSNotification *notification) {
             UnityNotificationManager* manager = [UnityNotificationManager sharedInstance];
             [manager updateScheduledNotificationList];
             [manager updateDeliveredNotificationList];
             [manager updateNotificationSettings];
         }];

        [nc addObserverForName: UIApplicationDidEnterBackgroundNotification
         object: nil
         queue: [NSOperationQueue mainQueue]
         usingBlock:^(NSNotification *notification) {
             [UnityNotificationManager sharedInstance].lastReceivedNotification = NULL;
         }];


        // Ivan: this is a fix for probllem when iOSNotificationCenter.GetLastRespondedNotification()
        // returns null if application was cold started from push notification.
        // The problem actually in Firebase Cloud Messaging  - it overwrites UNUserNotificationCenter.delegate
        // with own value
        // https://github.com/firebase/firebase-unity-sdk/issues/377#issuecomment-1165818349
        [nc addObserverForName: UIApplicationDidFinishLaunchingNotification
         object: nil
         queue: [NSOperationQueue mainQueue]
         usingBlock:^(NSNotification *notification) {
            [UNUserNotificationCenter currentNotificationCenter].delegate = [UnityNotificationManager sharedInstance];
         }];
        // Ivan
		
        [nc addObserverForName: kUnityWillFinishLaunchingWithOptions
         object: nil
         queue: [NSOperationQueue mainQueue]
         usingBlock:^(NSNotification *notification) {
             [UNUserNotificationCenter currentNotificationCenter].delegate = [UnityNotificationManager sharedInstance];

             BOOL authorizeOnLaunch = [[[NSBundle mainBundle] objectForInfoDictionaryKey: @"UnityNotificationRequestAuthorizationOnAppLaunch"] boolValue];
             BOOL supportsPushNotification = [[[NSBundle mainBundle] objectForInfoDictionaryKey: @"UnityAddRemoteNotificationCapability"] boolValue];
             BOOL registerRemoteOnLaunch = supportsPushNotification == YES ?
                 [[[NSBundle mainBundle] objectForInfoDictionaryKey: @"UnityNotificationRequestAuthorizationForRemoteNotificationsOnAppLaunch"] boolValue] : NO;

             NSInteger defaultAuthorizationOptions = [[[NSBundle mainBundle] objectForInfoDictionaryKey: @"UnityNotificationDefaultAuthorizationOptions"] integerValue];

             if (defaultAuthorizationOptions <= 0)
                 defaultAuthorizationOptions = (UNAuthorizationOptionSound + UNAuthorizationOptionAlert + UNAuthorizationOptionBadge);

             if (authorizeOnLaunch)
             {
                 UnityNotificationManager* manager = [UnityNotificationManager sharedInstance];
                 [manager requestAuthorization: defaultAuthorizationOptions withRegisterRemote: registerRemoteOnLaunch forRequest: NULL];
             }
         }];

        [nc addObserverForName: kUnityDidRegisterForRemoteNotificationsWithDeviceToken
         object: nil
         queue: [NSOperationQueue mainQueue]
         usingBlock:^(NSNotification *notification) {
             NSLog(@"didRegisterForRemoteNotificationsWithDeviceToken");
             UnityNotificationManager* manager = [UnityNotificationManager sharedInstance];
             [manager finishRemoteNotificationRegistration: UNAuthorizationStatusAuthorized notification: notification];
         }];

        [nc addObserverForName: kUnityDidFailToRegisterForRemoteNotificationsWithError
         object: nil
         queue: [NSOperationQueue mainQueue]
         usingBlock:^(NSNotification *notification) {
             NSLog(@"didFailToRegisterForRemoteNotificationsWithError");
             UnityNotificationManager* manager = [UnityNotificationManager sharedInstance];
             [manager finishRemoteNotificationRegistration: UNAuthorizationStatusDenied notification: notification];
         }];
    });
    return sharedInstance;
}
@end
#endif
