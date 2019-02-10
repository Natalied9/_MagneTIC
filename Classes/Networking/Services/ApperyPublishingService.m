//
//  ApperyPublishingService.m
//

#import "ApperyPublishingService.h"
#import "NetworkService_Private.h"
#import "AssetsArchiveDownloadOperation.h"

@implementation ApperyPublishingService

#pragma mark - Class logic

- (void)downloadSingleAssetsArchiveWithUpdateURL:(NSString *)urlString
                                  currentVersion:(NSDate *)version
                                   reciveHandler:(NetworkOperationCompletionHandler)reciveCallback
                               completionHandler:(NetworkOperationCompletionHandler)compliteCallback
{
    NSURL *Url = [NSURL URLWithString:urlString];
    AssetsArchiveDownloadOperation *daop = [[AssetsArchiveDownloadOperation alloc] initWithURL:Url currentVersion:version];
    daop.reciveHandler = reciveCallback;
    daop.completionHandler = compliteCallback;
    
    [self execute:daop];
}

@end
