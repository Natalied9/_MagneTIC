//
//  Alert.m
//

#import "Alert.h"
#import <objc/runtime.h>

#import "ApplicationDelegate.h"
#import "NSObject+Utils.h"
#import "UIDevice+System.h"

#pragma mark - CMAlertAction

@interface AlertAction : NSObject

@property (nonatomic, strong) NSString* title;
@property (nonatomic, strong) dispatch_block_t handler;

- (id) initWithTitle:(NSString*) title handler:(dispatch_block_t) handler;
+ (AlertAction*) actionWithTitle:(NSString*) title handler:(dispatch_block_t) handler;

@end

@implementation AlertAction

@synthesize title = _title;
@synthesize handler = _handler;

- (id) initWithTitle:(NSString*) title handler:(dispatch_block_t) handler
{
    self = [super init];
    if( nil == self )
    {
        return nil;
    }
    
    _title = title;
    _handler = handler;
    return self;
}

+ (AlertAction*) actionWithTitle:(NSString*) title handler:(dispatch_block_t) handler
{
    return [[self alloc] initWithTitle:title handler:handler];
}

- (void) dealloc
{
    _title = nil;
    _handler = nil;
}

@end

#pragma mark - Alert

@interface Alert () <UIAlertViewDelegate>

@property (nonatomic, strong, readwrite) NSString* title;
@property (nonatomic, strong, readwrite) NSString* message;

@property (nonatomic, strong) NSMutableArray* handlers;

@end

@implementation Alert

@synthesize title = _title;
@synthesize message = _message;

@synthesize handlers = _handlers;

#pragma mark - Lifecycle

- (id) initWithTitle:(NSString*) title message:(NSString*) message
{
    self = [super init];
    if( nil == self )
    {
        return nil;
    }
    
    _title = ( nil == title) ? @"" : title;
    _message = message;
    _handlers = [[NSMutableArray alloc] init];
    
    return self;
}

+ (Alert*) alertWithTitle:(NSString*) title message:(NSString*) message
{
    return [[self alloc] initWithTitle:title message:message];
}

- (void) dealloc
{
    _title = nil;
    _message = nil;
    _handlers = nil;
}

#pragma mark - Public class logic

- (void) addButtonWithTitle:(NSString*) title handler:(dispatch_block_t) handler
{
    if( nil == title )
    {
        return;
    }
    
    AlertAction* action = [AlertAction actionWithTitle:title handler:handler];
    [self.handlers addObject:action];
}

- (void) show
{
    if( ![NSThread isMainThread] )
    {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self show];
        });
        return;
    }
    
    if( 0 >= [self.handlers count] )
    {
        // There is no any button for alert view added!
        return;
    }
    
#if defined(__IPHONE_8_0)
    // Only for iOS8 and further - use UIAlertController
    [UIDevice executeUnderIOS8AndHigher:^{
        ApplicationDelegate* delegate = [(NSObject*)[UIApplication sharedApplication].delegate as:[ApplicationDelegate class]];
        UIWindow* win = delegate.window;
        UIViewController* controller = win.rootViewController;
        
        UIAlertController* alertController = [UIAlertController alertControllerWithTitle:self.title message:self.message preferredStyle:UIAlertControllerStyleAlert];
        for( AlertAction* action in self.handlers )
        {
            dispatch_block_t h = action.handler;
            UIAlertAction* alertAction = [UIAlertAction actionWithTitle:action.title style:UIAlertActionStyleDefault handler:^(UIAlertAction* a) {
                #pragma unused(a)
                if( nil != h )
                {
                    h();
                }
            }];
            [alertController addAction:alertAction];
        }
        objc_setAssociatedObject(alertController, "CMAlert", self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [controller presentViewController:alertController animated:YES completion:nil];
    }];
    
    // If iOS is lower than 8.0 then use UIAlertView
    [UIDevice executeUnderIOS7AndLower:^{
        UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:self.title message:self.message delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
        for( AlertAction* action in self.handlers )
        {
            [alertView addButtonWithTitle:action.title];
        }
        objc_setAssociatedObject(alertView, "CMAlert", self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [alertView show];
    }];
#else // defined(__IPHONE_8_0)
    // If there is used iOS SDK lower than iOS SDK 8.0 then use UIAlertView.
    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:self.title message:self.message delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
    for( CMAlertAction* action in self.handlers )
    {
        [alertView addButtonWithTitle:action.title];
    }
    objc_setAssociatedObject(alertView, "CMAlert", self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [alertView show];
#endif // defined(__IPHONE_8_0)
}

#pragma mark - UIAlertViewDelegate

// Called when a button is clicked. The view will be automatically dismissed after this call returns
- (void) alertView:(UIAlertView*) alertView clickedButtonAtIndex:(NSInteger) buttonIndex
{
    #pragma unused(alertView)
    if( 0 <= buttonIndex && [self.handlers count] > (NSUInteger)buttonIndex)
    {
        AlertAction* action = [self.handlers[(NSUInteger)buttonIndex] as:[AlertAction class]];
        if( nil != action.handler )
        {
            action.handler();
        }
    }
}

@end
