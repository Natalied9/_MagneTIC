//
//  Alert.h
//

#import <Foundation/Foundation.h>

@interface Alert : NSObject

@property (nonatomic, strong, readonly) NSString* title;
@property (nonatomic, strong, readonly) NSString* message;

- (id) initWithTitle:(NSString*) title message:(NSString*) message;
+ (Alert*) alertWithTitle:(NSString*) title message:(NSString*) message;

- (void) addButtonWithTitle:(NSString*) title handler:(void(^)(void)) handler;
- (void) show;

@end
