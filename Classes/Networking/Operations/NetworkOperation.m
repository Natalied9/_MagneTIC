//
//  NetworkOperation.m
//

#import "NetworkOperation.h"
#import "NSString+XMLEscape.h"
#import "NSThread+BlockExecution.h"

#define USE_HTTP_OPERATION_DEBUG 0
/// Debugging macro
#if USE_HTTP_OPERATION_DEBUG
#  define OPQDLog(...) NSLog(__VA_ARGS__)
# else
#  define OPQDLog(...) /* nothing to log */
#endif

const NSTimeInterval kNetworkOperationDefaultTimeout = 45.0f;
NSString* const kNetworkOperationDefaultMethod = @"POST";
NSString* const kNetworkOperationErrorHTTPResponseKey = @"HTTPOperationErrorHTTPResponseKey";
NSString* const kNetworkOperationErrorHTTPBodyKey = @"HTTPOperationErrorHTTPBodyKey";
const NSInteger kNetworkOperationCancelledErrorCode = -1000;
NSString *const kNetworkOperationCancelledErrorDescription = @"Cancelled";


@interface NetworkOperation () <NSURLConnectionDelegate>

@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, strong) NSError *error;

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *actualResponseBody;
@property (nonatomic, strong) NSThread *thread;
@property (nonatomic, strong) NSRunLoop *runLoop;

@end

@implementation NetworkOperation

@synthesize status = _status;
@synthesize request = _request;
@synthesize response = _response;
@synthesize error = _error;
@synthesize connection = _connection;
@dynamic responseBody;
@synthesize actualResponseBody = _actualResponseBody;
@synthesize responseBodyHandler = _responseBodyHandler;
@synthesize completionHandler = _completionHandler;
@synthesize thread = _thread;
@synthesize runLoop = _runLoop;
#if USE_SIMULATED_RESPONSE
@synthesize useSimulatedResponse = _useSimulatedResponse;
#endif

#pragma mark - Initialization and configuration stuff

- (instancetype)init {
    return [self initWithURL:nil];
}

- (instancetype)initWithURL:(NSURL *)url {
    if ((self = [super init]) == nil) {
        return nil;
    }

    if (url != nil) {
        NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:url];
        [r setHTTPMethod:kNetworkOperationDefaultMethod];
        self.request = r;
    }
    else {
        [self request];
    }
    
    return self;
}

- (void)dealloc {
    [_connection cancel];
}

- (NSData *)responseBody {
    return self.actualResponseBody;
}

- (NetworkOperationCompletionHandler)completionHandler {
    NetworkOperationCompletionHandler blk = nil;
    @synchronized(self) {
        blk = [_completionHandler copy];
    }
    return blk;
}

- (void)setCompletionHandler:(NetworkOperationCompletionHandler)completionHandler {
    @synchronized(self) {
        _completionHandler = [completionHandler copy];
    }
    
    __block NetworkOperation* blockSelf = self;
    self.completionBlock = ^(void) {
        NetworkOperationCompletionHandler blk = blockSelf.completionHandler;
        if (blk) {
            blk(blockSelf);
            @synchronized(blockSelf) {
                blockSelf->_completionHandler = nil;
            }
        }
        blockSelf.completionBlock = nil;
        blockSelf = nil;
    };
}

- (void)setStatus:(NetworkOperationStatus)status {
    @synchronized(self) {
        if (status == _status) {
            return;
        }
        
        static const int transitionArray[4*4] = {
            // None ->
            /* None */ 0, /* InProgress */ 1, /* Done */ 3, /* Failed */ 3,
            
            // InProgress ->
            /* None */ 1, /* InProgress */ 0, /* Done */ 3, /* Failed */ 3,
            
            // Done ->
            /* None */ 0, /* InProgress */ 3, /* Done */ 0, /* Failed */ 0,
            
            // Failed ->
            /* None */ 0, /* InProgress */ 3, /* Done */ 0, /* Failed */ 0,
        };
        int trx = transitionArray[ (_status & 3) * 4 + (status & 3) ];
        
        if (trx & 1) {
            [self willChangeValueForKey:@"isExecuting"];
        }
        if (trx & 2) {
            [self willChangeValueForKey:@"isFinished"];
        }
        _status = status;
        if (trx & 1) {
            [self didChangeValueForKey:@"isExecuting"];
        }
        if (trx & 2) {
            [self didChangeValueForKey:@"isFinished"];
        }
    }
}

#pragma mark - Overloaded NSOperation methods

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isExecuting {
    return _status == InProgress;
}

- (BOOL)isFinished {
    NetworkOperationStatus status = self.status;
    return status == Done || status == Failed;
}

- (void)start {
    OPQDLog(@"%@: start requested", NSStringFromClass(self.class));
    self.status = InProgress;
    [self startOperation];
}

- (void)cancel {
    BOOL actuallyCancel;

    OPQDLog(@"%@: cancel requested", NSStringFromClass(self.class));
    
    @synchronized(self) {
        BOOL oldCancelled = [self isCancelled];
        [super cancel];
        actuallyCancel = !oldCancelled && self.status == InProgress;
    }
    if (actuallyCancel) {
        [self finishWithCancel];
    }
}

#pragma mark - Methods to be overloaded by the descendent classes

- (NSURL *)httpRequestURL {
    assert(0);
    return nil;
}

- (NSURLRequest *)request {
    if(_request != nil) {
        return _request;
    }
    NSMutableURLRequest* r = [NSMutableURLRequest requestWithURL:[self httpRequestURL]];
    [r setTimeoutInterval:kNetworkOperationDefaultTimeout];
    [r setHTTPMethod:kNetworkOperationDefaultMethod];
    self.request = r;
    return r;
}

- (void)setRequestMethod:(NSString *)method {
    NSMutableURLRequest *r = (NSMutableURLRequest *)self.request;
    assert([r isKindOfClass:[NSMutableURLRequest class]]);
    r.HTTPMethod = method;
}

- (void)setRequestBodyWithDictionary:(NSDictionary *)dict {
    NSMutableString *requestBody = [NSMutableString stringWithCapacity:1024];
    for (NSString* key in [dict allKeys]) {
        // To cover NSDictionary, produced by JSON parser, here we convert any type
        // of dictionary's content to NSString and then insert it into query string.
        id val = [dict valueForKey:key];
        NSString *valString = nil;
        // If given object is NSNumber we need to explicitly check it to BOOL type
        // because server side can't understand 0/1 and requires "true"/"false".
        if ([val isKindOfClass:[NSNumber class]]) {
            // BOOL is signed char, so if number is numberchartype - it can be interpreted as BOOL.
            if (kCFNumberCharType == CFNumberGetType((CFNumberRef)val)) {
                valString = ( [(NSNumber *)val boolValue] ) ? @"true" : @"false";
            }
            else {
                // If number is not BOOL - just take it string representation.
                valString = [(NSNumber *)val stringValue];
            }
        }
        
        valString = [NSString stringWithPercentEscapesForString:valString];
        if (requestBody.length) {
            [requestBody appendFormat:@"&%@=%@", key, valString];
        }
        else {
            [requestBody appendFormat:@"%@=%@", key, valString];
        }
    }

    NSMutableURLRequest *request = (NSMutableURLRequest *)[self request];
    assert([request isKindOfClass:[NSMutableURLRequest class]]);
    if ([requestBody length]) {
        [request setHTTPBody:[requestBody dataUsingEncoding:NSUTF8StringEncoding]];
    }
        
    [request setValue:@"application/x-www-form-urlencoded;charset=utf-8;" forHTTPHeaderField:@"Content-Type"];
}

- (void)setRequestQueryWithDictionary:(NSDictionary *)dict {
    NSMutableString *requestQuery = [NSMutableString stringWithCapacity:1024];
    for (NSString* key in [dict allKeys]) {
        // To cover NSDictionary, produced by JSON parser, here we convert any type
        // of dictionary's content to NSString and then insert it into query string.
        id val = [dict valueForKey:key];
        NSString *valString = nil;
        // If given object is NSNumber we need to explicitly check it to BOOL type
        // because server side can't understand 0/1 and requires "true"/"false".
        if ([val isKindOfClass:[NSNumber class]]) {
            // BOOL is signed char, so if number is numberchartype - it can be interpreted as BOOL.
            if (kCFNumberCharType == CFNumberGetType((CFNumberRef)val)) {
                valString = ( [(NSNumber *)val boolValue] ) ? @"true" : @"false";
            }
            else {
                // If number is not BOOL - just take it string representation.
                valString = [(NSNumber *)val stringValue];
            }
        }
        else {
            // If object is not number - take it description
            // ( string will remain the same, other objects are converted to strings )
            valString = [val description];
        }
        
        valString = [NSString stringWithPercentEscapesForString:valString];
        if (requestQuery.length) {
            [requestQuery appendFormat:@"&%@=%@", key, valString];
        }
        else {
            [requestQuery appendFormat:@"%@=%@", key, valString];
        }
    }
    
    if ([requestQuery length]) {
        NSMutableURLRequest *request = (NSMutableURLRequest *)[self request];
        assert([request isKindOfClass:[NSMutableURLRequest class]]);
        
        [requestQuery insertString:@"?" atIndex:0];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [request.URL absoluteString], requestQuery]];
        [request setURL:url];
    }
}

- (void)setRequestBodyWithString:(NSString *)requestString {
    NSMutableURLRequest *request = (NSMutableURLRequest *)[self request];
    assert([request isKindOfClass:[NSMutableURLRequest class]]);
    if ([requestString length]) {
        [request setHTTPBody:[requestString dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
}

- (void)setRequestQueryWithString:(NSString *)requestString {
    if ([requestString length]) {
        NSMutableURLRequest *request = (NSMutableURLRequest *)[self request];
        assert([request isKindOfClass:[NSMutableURLRequest class]]);
        
        NSString *queryString = [NSString stringWithFormat:@"?%@", requestString];
        [request setURL:[NSURL URLWithString:queryString relativeToURL:request.URL]];
    }
}

- (void)setRequestHeader:(NSString *)name value:(NSString *)value {
    if (name.length > 0 && value.length > 0) {
        NSMutableURLRequest *request = (NSMutableURLRequest *)[self request];
        assert([request isKindOfClass:[NSMutableURLRequest class]]);
        [request setValue:value forHTTPHeaderField:name];
    }
}

- (void)finishWithSuccess {
    [self.connection cancel];
    self.connection = nil;
    self.status = Done;
    OPQDLog(@"%@: finished with success", NSStringFromClass(self.class));
}

- (void)finishWithFailure:(NSError *)error {
    self.error = error;
    [self.connection cancel];
    self.connection = nil;
    self.status = Failed;
    OPQDLog(@"%@: finished with error: %@", NSStringFromClass(self.class), [error localizedDescription]);
}

- (void) finishWithCancel {
    [self finishWithFailure:[NSError errorWithDomain:@"NetworkOperationErrorDomain" code:kNetworkOperationCancelledErrorCode userInfo:@{ NSLocalizedDescriptionKey: kNetworkOperationCancelledErrorDescription }]];
}

#pragma mark - NSURLConnectionDelegate protocol implementation

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    #pragma unused(connection)
    #pragma unused(error)
    [self.connection cancel];
    self.connection = nil;
    OPQDLog(@"%@: Connection did failed with error: %@", NSStringFromClass(self.class), [error localizedDescription]);

    [self finishWithFailure:error];
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection {
    #pragma unused(connection)
    if ([self isCancelled]){
        [self finishWithCancel];
    }
    return NO;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    #pragma unused(connection, response)
    if ([self isCancelled]) {
        [self finishWithCancel];
        return nil;
    }
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    #pragma unused(connection)
    if ([self isCancelled]) {
        [self finishWithCancel];
        return;
    }
    self.response = (NSHTTPURLResponse *)response;
    assert( [self.response isKindOfClass:[NSHTTPURLResponse class]] );
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    #pragma unused(connection)
    if ([self isCancelled]) {
        [self finishWithCancel];
        return;
    }
    if (self.responseBodyHandler) {
        self.responseBodyHandler(self, data);
    }
    else {
        if (self.actualResponseBody == nil) {
            self.actualResponseBody = [NSMutableData dataWithData:data];
        }
        else {
            [self.actualResponseBody appendData:data];
        }
    }
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    #pragma unused(connection, cachedResponse)
    if ([self isCancelled]) {
        [self finishWithCancel];
    }
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
#if USE_HTTP_OPERATION_DEBUG
    OPQDLog(@"%@: response URL: %@", NSStringFromClass(self.class), _response.URL);
    OPQDLog(@"%@: response HTTP status code: %ld", NSStringFromClass(self.class), (long)_response.statusCode);
    if( _actualResponseBody.length != 0 )
    {
        NSString *bodyStr = [[NSString alloc] initWithData:_actualResponseBody encoding:NSUTF8StringEncoding];
        OPQDLog(@"%@: response body: %@", NSStringFromClass(self.class), bodyStr);
    }
    OPQDLog(@"%@: response headers: %@", NSStringFromClass(self.class), _response.allHeaderFields);
#endif
    
    NSError* opError = nil;
    switch (self.response.statusCode) {
        case 200:
            break;
        default:
        {
            NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
            if (self.response != nil) {
                userInfo[kNetworkOperationErrorHTTPResponseKey] = self.response;
            }
            if (self.responseBody != nil) {
                userInfo[kNetworkOperationErrorHTTPBodyKey] = self.responseBody;
            }
            opError = [NSError errorWithDomain:@"NetworkOperationErrorDomain" code:self.response.statusCode userInfo:userInfo];
        }
            break;
    }
    
    // If HTTP Status == 200 then opError is nil and request was successful.
    if (opError == nil) {
        [self finishWithSuccess];
    }
    else {
        [self finishWithFailure:opError];
    }
}

#pragma mark - Utility logic

- (void)cancelOperation {
    [self.connection cancel];
    self.connection = nil;
    self.error = [NSError errorWithDomain:@"NetworkOperationErrorDomain" code:kNetworkOperationCancelledErrorCode userInfo:@{ NSLocalizedDescriptionKey: kNetworkOperationCancelledErrorDescription }];
    self.status = Failed;
    OPQDLog(@"%@: operation terminated", NSStringFromClass(self.class));
}

- (void)startOperation {
    assert(self.response == nil);
    assert(self.connection == nil);

    if ([self isCancelled]) {
        [self finishWithCancel];
        OPQDLog(@"%@: operation was cancelled before start", NSStringFromClass(self.class));
        return;
    }
    
    NSURLRequest *request = [self request];
    NSString *host = request.URL.host;
    if ([host hasSuffix:@"."]) {
        [self setRequestHeader:@"Host" value:[host substringToIndex:host.length-1]];
    }
    
    if (![NSURLConnection canHandleRequest:request]) {
        [self finishWithCancel];
        OPQDLog(@"%@: requested URL can not be handled", NSStringFromClass(self.class));
        return;
    }
    
#if USE_HTTP_OPERATION_DEBUG
    {
        OPQDLog(@"%@: request URL: %@", NSStringFromClass(self.class), request.URL);
        OPQDLog(@"%@: request method: %@", NSStringFromClass(self.class), request.HTTPMethod);
        if (self.request.HTTPBody.length) {
            NSString *logStr = [[NSString alloc] initWithData:_request.HTTPBody encoding:NSUTF8StringEncoding];
            OPQDLog(@"%@: request body: %@", NSStringFromClass(self.class), logStr);
        }
        OPQDLog(@"%@: request headers: %@", NSStringFromClass(self.class), _request.allHTTPHeaderFields);
        
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        NSArray *cookies = [cookieStorage cookiesForURL:self.request.URL];
        for (NSHTTPCookie *cookie in cookies) {
            OPQDLog(@"*******COOKIE: %@: %@", [cookie name], [cookie value]);
        }
        
    }
#endif

    BOOL started = [self startThread:^(BOOL ok) {
        if (ok) {
            if (self.runLoop != nil) {
                self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
                NSString *runLoopMode = [self.runLoop currentMode];
                if (runLoopMode == nil) {
                    runLoopMode = (__bridge NSString*)kCFRunLoopDefaultMode;
                }
                [self.connection scheduleInRunLoop:self.runLoop forMode:runLoopMode];
                [self.connection start];
                OPQDLog(@"%@: started", NSStringFromClass(self.class));
            }
        }
    }];

    if (!started) {
        OPQDLog(@"Failed to start network operation thread.");
        [self finishWithCancel];
        return;
    }
}

#pragma mark - Thread management

- (void)nop {
    // Do nothing.
}

- (void) networkOperationThreadBody:(id)argument {
    @autoreleasepool {
        self.runLoop = [NSRunLoop currentRunLoop];
        [[NSThread currentThread] setName:NSStringFromClass(self.class)];
    }
    NSTimer *t = [NSTimer scheduledTimerWithTimeInterval:NSTimeIntervalSince1970 target:self selector:@selector(nop) userInfo:nil repeats:NO];
    while (![[NSThread currentThread] isCancelled]) {
        @autoreleasepool {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.5, 0);
        }
    }
    [t invalidate];
    @autoreleasepool {
        self.runLoop = nil;
    }
    [NSThread exit];
}

- (BOOL) startThread:(void(^)(BOOL)) handler {
    if (self.thread != nil && self.thread.executing) {
        if (self.runLoop == nil) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                self.runLoop = [NSRunLoop currentRunLoop];
                if ( handler != nil) {
                    handler(YES);
                }
            });
            return YES;
        }
    }
    
    self.thread = [[NSThread alloc] initWithTarget:self selector:@selector(networkOperationThreadBody:) object:nil];
    if (self.thread == nil) {
        return NO;
    }
    
    [self.thread start];
    if (handler == nil) {
        while (self.thread != nil && self.runLoop == nil) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, 0);
        }
        return (self.thread != nil);
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (self.thread != nil && self.runLoop == nil) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, 0);
        }
        handler(self.thread != nil);
    });
    
    return self.thread != nil;
}

- (void) stopThread:(void(^)(void)) handler {
    if (self.thread != nil) {
        [self.thread cancel];
        self.thread = nil;
    }
    
    if (self.runLoop == nil) {
        if (handler != nil) {
            handler();
        }
        return;
    }
    
    if (handler == nil) {
        while (self.runLoop != nil) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, 0);
        }
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (self.runLoop != nil) {
            [NSThread sleepForTimeInterval:0.1];
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            handler();
        });
    });
}

@end
