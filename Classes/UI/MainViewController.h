//
//  MainViewController.h
//

#import <Cordova/CDVViewController.h>

@class WebProjectInfo;

@interface MainViewController : CDVViewController

@property (nonatomic, strong, readonly) WebProjectInfo *projectInfo;

@end