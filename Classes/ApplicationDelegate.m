//
//  ApplicationDelegate.m
//

#import "ApplicationDelegate.h"
#import "MainViewController.h"
#import "SetupViewController.h"

#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVURLProtocol.h>

#ifdef USE_PUSH_NOTIFICATION_PLUGIN
#import "PushNotification.h"
#endif

#import "NSObject+Utils.h"
#import "WebProjectSetupHelper.h"
#import "WebProjectSetupHelperDelegate.h"
#import "LoadingView.h"

#import "ApplicationDelegate.h"
#import "MainViewController.h"
#import "NSObject+Utils.h"

#import "DeviceModelInfo.h"
#import "UIDevice+System.h"
#import "Alert.h"

@interface ApplicationDelegate () <WebProjectSetupHelperDelegate>

@property (nonatomic, strong) WebProjectSetupHelper *helper;
@property (nonatomic, strong) LoadingView *loadingView;

@end

@implementation ApplicationDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;
@synthesize helper = _helper;
@synthesize loadingView = _loadingView;

- (instancetype)init
{
    self = [super init];
    if(self == nil)
    {
        return nil;
    }

    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    [cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    
    int cacheSizeMemory = 8 * 1024 * 1024;  //  8MB
    int cacheSizeDisk = 32 * 1024 * 1024;   // 32MB
    
    NSURLCache* sharedCache = [[NSURLCache alloc] initWithMemoryCapacity:cacheSizeMemory diskCapacity:cacheSizeDisk diskPath:@"nsurlcache"];
    [NSURLCache setSharedURLCache:sharedCache];
    
    return self;
}


#pragma mark - UIApplicationDelegate implementation

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSError *error = nil;
    NSNumber *val = nil;
    
    [[NSURL fileURLWithPath:[docs stringByAppendingPathComponent:@"WebApplication"]] getResourceValue:&val forKey:NSURLIsExcludedFromBackupKey error:&error];
    [[NSURL fileURLWithPath:[docs stringByAppendingPathComponent:@"WebApplication"]] setResourceValue:@(YES) forKey:NSURLIsExcludedFromBackupKey error:&error];
    
//    NSString *lib = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];
//    [[NSURL fileURLWithPath:lib] getResourceValue:&val forKey:NSURLIsExcludedFromBackupKey error:&error];
//    [[NSURL fileURLWithPath:lib] setResourceValue:@(YES) forKey:NSURLIsExcludedFromBackupKey error:&error];

    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    self.window = [[UIWindow alloc] initWithFrame:screenBounds];
    self.window.autoresizesSubviews = YES;

    MainViewController *mvc = [[MainViewController alloc] initWithNibName:nil bundle:nil];
    self.viewController = mvc;

    self.helper = [[WebProjectSetupHelper alloc] initWithProjectInfo:mvc.projectInfo delegate:self];
    
    SetupViewController *svc = [[SetupViewController alloc] initWithNibName:nil bundle:nil];
    self.window.rootViewController = svc;
    [self.window makeKeyAndVisible];

#ifdef USE_PUSH_NOTIFICATION_PLUGIN
    // PushNotification - Handle launch from a push notification
    NSDictionary *userInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if(userInfo) {
        PushNotification *pushHandler = [self.viewController getCommandInstance:@"PushNotification"];
        NSMutableDictionary *mutableUserInfo = [userInfo mutableCopy];
        [mutableUserInfo setValue:@"1" forKey:@"applicationLaunchNotification"];
        [mutableUserInfo setValue:@"0" forKey:@"applicationStateActive"];
        [pushHandler.pendingNotifications addObject:mutableUserInfo];
    }
#endif

    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (![self.helper.processing boolValue])
    {
        [self.helper performSetup];
    }
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
    if(!url)
    {
        return NO;
    }

    MainViewController* mainController = [self.viewController as:[MainViewController class]];
    if (mainController == nil)
    {
        return NO;
    }
    // calls into javascript global function 'handleOpenURL'
    NSString *jsString = [NSString stringWithFormat:@"handleOpenURL(\"%@\");", url];
    [mainController.webView stringByEvaluatingJavaScriptFromString:jsString];

    // all plugins will get the notification, and their handlers will be called
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPluginHandleOpenURLNotification object:url]];

    return YES;
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

#ifdef USE_PUSH_NOTIFICATION_PLUGIN

#pragma mark - PushNotification delegation

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    PushNotification* pushHandler = [self.viewController getCommandInstance:@"PushNotification"];
    [pushHandler didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    PushNotification *pushHandler = [self.viewController getCommandInstance:@"PushNotification"];
    [pushHandler didFailToRegisterForRemoteNotificationsWithError:error];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    PushNotification *pushHandler = [self.viewController getCommandInstance:@"PushNotification"];
    NSMutableDictionary *mutableUserInfo = [userInfo mutableCopy];

    // Get application state for iOS4.x+ devices, otherwise assume active
    UIApplicationState appState = UIApplicationStateActive;
    if ([application respondsToSelector:@selector(applicationState)])
    {
        appState = application.applicationState;
    }

    [mutableUserInfo setValue:@"0" forKey:@"applicationLaunchNotification"];

    if (appState == UIApplicationStateActive)
    {
        [mutableUserInfo setValue:@"1" forKey:@"applicationStateActive"];
        [pushHandler didReceiveRemoteNotification:mutableUserInfo];
    }
    else
    {
        [mutableUserInfo setValue:@"0" forKey:@"applicationStateActive"];
        [mutableUserInfo setValue:[NSNumber numberWithDouble: [[NSDate date] timeIntervalSince1970]] forKey:@"timestamp"];
        [pushHandler.pendingNotifications addObject:mutableUserInfo];
    }
}

#endif

#pragma mark - WebProjectSetupHelperDelegate

- (void)willStartCostlyAction
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *updateMessage = @"Checking and loading new updates. This might take a few minutes.";
        self.loadingView = [[LoadingView alloc] initWithView:self.window.rootViewController.view text:NSLocalizedString(updateMessage, updateMessage)];
        [self.loadingView start];
    });
}

- (void)willFinishCostlyAction
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.loadingView stopAndDismiss];
        self.loadingView = nil;
    });
}

- (void)didUpdateAssets
{
    // Reload main webView with new assets.
    dispatch_async(dispatch_get_main_queue(), ^{
        MainViewController *mvc = [[MainViewController alloc] initWithNibName:nil bundle:nil];
        self.viewController = mvc;
    });
}

- (void)didFinishSetupProjectWithError:(NSError *)error
{
    if (error != nil)
    {
        Alert *alert = [Alert alertWithTitle:[error localizedDescription] message:nil];
        [alert addButtonWithTitle:NSLocalizedString(@"Ok", @"Ok") handler:nil];
        [alert show];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        self.window.rootViewController = self.viewController;
    });
}

@end
