//
//  AssetsArchiveDownloadOperation.h
//

#import "NetworkOperation.h"

@interface AssetsArchiveDownloadOperation : NetworkOperation

@property (nonatomic, strong, readonly) NSDate *publishedVersion;
/// Callback for operation recive responce.
@property (nonatomic, copy) NetworkOperationCompletionHandler reciveHandler;

- (instancetype)initWithURL:(NSURL *)url currentVersion:(NSDate *)version;

@end
