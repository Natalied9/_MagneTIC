//
//  WebProjectSetupHelper.h
//  DownloadableAssets
//
//  Created by Pavel Gorb on 8/5/15.
//
//

#import <Foundation/Foundation.h>

extern NSString *const kWebProjectSetupHelperErrorDomain;
extern const NSInteger kWebProjectSetupHelperErrorNoProjectInfo;
extern const NSInteger kWebProjectSetupHelperErrorImpossibleToUnarchiveAssetsFromBundle;
extern const NSInteger kWebProjectSetupHelperErrorNoAssetsData;
extern const NSInteger kWebProjectSetupHelperErrorImpossibleToUnarchiveAssets;
extern const NSInteger kWebProjectSetupHelperErrorUnexpectedError;
extern const NSInteger kWebProjectSetupHelperErrorNoConnection;

@class WebProjectInfo;
@protocol WebProjectSetupHelperDelegate;

@interface WebProjectSetupHelper : NSObject

@property (nonatomic, weak, readonly) id<WebProjectSetupHelperDelegate> delegate;
@property (atomic, strong, readonly) NSNumber *processing;

- (instancetype)initWithProjectInfo:(WebProjectInfo *)info delegate:(id<WebProjectSetupHelperDelegate>)delegate NS_DESIGNATED_INITIALIZER;
- (void)performSetup;

@end
