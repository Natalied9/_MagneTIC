//
//  AssetsArchiveDownloadOperation.m
//

#import "AssetsArchiveDownloadOperation.h"
#import "NSObject+Utils.h"

@interface AssetsArchiveDownloadOperation ()

@property (nonatomic, strong, readwrite) NSDate *publishedVersion;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

@implementation AssetsArchiveDownloadOperation

@synthesize reciveHandler = _reciveHandler;

- (instancetype)initWithURL:(NSURL *)url currentVersion:(NSDate *)version
{
    self = [super initWithURL:url];
    if (self == nil)
    {
        return nil;
    }

    // Last-Modified:Mon, 10 Aug 2015 14:20:57 GMT
    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateFormat:@"EEE, dd MMM yyyy kk:mm:ss zzz"];
    // Date should be always in RFC 1123 format (Tue, 18 Aug 2015 13:18:17 GMT) (Date should be in GMT timezone as per RFC).
    NSTimeZone *gmtZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    [_dateFormatter setTimeZone:gmtZone];
    // Always use US locale
    NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    [_dateFormatter setLocale:usLocale];
    
    if (version != nil)
    {
        NSString *versionString = [_dateFormatter stringFromDate:version];
        [self setRequestHeader:@"If-Modified-Since" value:versionString];
    }

    [self setRequestMethod:@"GET"];
    return self;
}

#pragma mark - 

- (NetworkOperationCompletionHandler)reciveHandler
{
    NetworkOperationCompletionHandler blk = nil;
    @synchronized(self)
    {
        blk = [_reciveHandler copy];
    }
    return blk;
}

- (void)setReciveHandler:(NetworkOperationCompletionHandler)reciveHandler
{
    @synchronized(self)
    {
        _reciveHandler = [reciveHandler copy];
    }
    
    __block AssetsArchiveDownloadOperation* blockSelf = self;
    self.completionBlock = ^(void)
    {
        NetworkOperationCompletionHandler blk = blockSelf.reciveHandler;
        if (blk) {
            blk(blockSelf);
            @synchronized(blockSelf)
            {
                blockSelf->_reciveHandler = nil;
            }
        }
        blockSelf.completionBlock = nil;
        blockSelf = nil;
    };
}

#pragma mark - Overrides

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [super connection:connection didReceiveResponse:response];
    
    if (response && [response isKindOfClass:[NSHTTPURLResponse class]])
    {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode == 200)
        {
            self.reciveHandler(self);
        }
    }
}

- (void)finishWithSuccess
{
    [self takePublishedVersionFromHeaders];
    [super finishWithSuccess];
}

- (void)finishWithFailure:(NSError *)error
{
    [self takePublishedVersionFromHeaders];
    [super finishWithFailure:error];
}

#pragma mark - Private class logic

- (void) takePublishedVersionFromHeaders
{
    NSString *versionCandidate = [[self.response.allHeaderFields objectForKey:@"Last-Modified"] as:[NSString class]];
    self.publishedVersion = [self.dateFormatter dateFromString:versionCandidate];
}

@end
