//
//  NetworkOperation.h
//

#import <Foundation/Foundation.h>

@class NetworkOperation;

/// Operation status codes.
typedef NS_ENUM(NSInteger, NetworkOperationStatus) {
    None,
    InProgress,
    Done,
    Failed
};

/**
 * Callback for operation completion.
 */
typedef void (^NetworkOperationCompletionHandler)(NetworkOperation *operation);

/**
 * Incoming responce body chunks processing code block
 */
typedef void (^NetworkOperationResponseBodyHandler)(NetworkOperation *operation, NSData *bodyChunk);

/// Key for looking up HTTP response object in the HTTP error descriptor userInfo dictionary.
extern NSString *const kNetworkOperationErrorHTTPResponseKey;

/// Key for looking up HTTP response body in the HTTP error descriptor userInfo dictionary.
extern NSString *const kNetworkOperationErrorHTTPBodyKey;

/// Default timeout value for the HTTP operations.
extern const NSTimeInterval kNetworkOperationDefaultTimeout;

/// Default HTTP method for HTTP operations.
extern NSString *const kNetworkOperationDefaultMethod;

extern const NSInteger kNetworkOperationCancelledErrorCode;

extern NSString *const kNetworkOperationCancelledErrorDescription;

/**
 * Base class for HTTP requests to YF proxy.
 */
@interface NetworkOperation : NSOperation <NSURLConnectionDataDelegate>

/// Network operation status.
@property (nonatomic, assign, readonly) NetworkOperationStatus status;

/// Underlying HTTP request.
@property (nonatomic, strong, readonly) NSURLRequest *request;

/// Response for the underlying HTTP request.
@property (nonatomic, strong, readonly) NSHTTPURLResponse *response;

/// Error description if one occured.
@property (nonatomic, strong, readonly) NSError *error;

/// HTTP response body, collected so far. This property is not used if responseBodyHandler provided.
@property (nonatomic, strong, readonly) NSData *responseBody;

/// Handler for response body chunks. If set, then responseBody is not accumulated.
@property (nonatomic, copy) NetworkOperationResponseBodyHandler responseBodyHandler;

/// Callback for operation completion.
@property (nonatomic, copy) NetworkOperationCompletionHandler completionHandler;

#if USE_SIMULATED_RESPONSE
@property (nonatomic, assign) BOOL useSimulatedResponse;
#endif

/**
 * Initialize HTTP operation with HTTP request target URL. This is designated initializer.
 *
 * @param url Target URL for HTTP request. By default HTTP request method is POST and body is empty.
 */
- (instancetype)initWithURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;

/**
 * Set the HTTP request method.
 *
 * @param method HTTP request method to set.
 */
- (void)setRequestMethod:(NSString *)method;

/**
 * Set the HTTP request body to have application/x-www-form-urlencoded content type
 * and content, derived from the dictionary.
 *
 * @param dict String to String dictionary with key-value pars for the request body content.
 */
- (void)setRequestBodyWithDictionary:(NSDictionary *)dict;

/**
 * Set the HTTP request query part of the URL, derived from the dictionary.
 *
 * @param dict String to String dictionary with key-value pars for the request URL query part.
 */
- (void)setRequestQueryWithDictionary:(NSDictionary *)dict;

/**
 * Add HTTP header field to the URL request.
 *
 * @param name HTTP request header name.
 * @param value HTTP request header value.
 */
- (void)setRequestHeader:(NSString *)name value:(NSString *)value;

/**
 * Terminate the operation and set operation status to Done.
 */
- (void)finishWithSuccess;

/**
 * Terminate the operation and set operation status to Failed.
 *
 * @param error Error, which caused the operation termination.
 */
- (void)finishWithFailure:(NSError *)error;

/**
 * Terminate operation due to cancel requested
 */
- (void)finishWithCancel;

/**
 * Compose the complete URL for the HTTP request.
 * Method to be overloaded by the descendent classes.
 */
- (NSURL *)httpRequestURL;

@end
