//
//  WebProjectSetupHelperDelegate.h
//  DownloadableAssets
//
//  Created by Pavel Gorb on 8/11/15.
//
//

#import <Foundation/Foundation.h>

@protocol WebProjectSetupHelperDelegate <NSObject>

- (void)willStartCostlyAction;
- (void)willFinishCostlyAction;

- (void)didUpdateAssets;
- (void)didFinishSetupProjectWithError:(NSError *)error;

@end
