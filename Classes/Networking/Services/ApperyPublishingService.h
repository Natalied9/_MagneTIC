//
//  ApperyPublishingService.h
//

#import "NetworkService.h"
#import "NetworkOperation.h"

@interface ApperyPublishingService : NetworkService

- (void)downloadSingleAssetsArchiveWithUpdateURL:(NSString *)urlString
                                  currentVersion:(NSDate *)version
                                   reciveHandler:(NetworkOperationCompletionHandler)reciveCallback
                               completionHandler:(NetworkOperationCompletionHandler)compliteCallback;

@end
