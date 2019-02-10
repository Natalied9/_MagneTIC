//
//  LoadingView.h
//

#import <UIKit/UIKit.h>

@interface LoadingView : UIView

- (instancetype)initWithView:(UIView *)view text:(NSString *)text;

- (void)start;
- (void)stopAndDismiss;

- (void)updateText:(NSString *)text;

- (BOOL)isOperating;

@end
