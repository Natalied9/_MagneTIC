//
//  ApplicationDelegate.h
//

#import <Cordova/CDVViewController.h>
#import <Cordova/CDVCommandDelegateImpl.h>
#import <Cordova/CDVCommandQueue.h>

@interface ApplicationDelegate : NSObject < UIApplicationDelegate >

@property (nonatomic, strong) IBOutlet UIWindow* window;
@property (nonatomic, strong) IBOutlet CDVViewController* viewController;

@end
