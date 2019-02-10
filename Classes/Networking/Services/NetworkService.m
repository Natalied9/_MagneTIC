//
//  NetworkService.m
//

#import "NetworkService.h"
#import "NetworkService_Private.h"

@interface NetworkService ()

@property (nonatomic, strong) NSOperationQueue *queue;

@end

@implementation NetworkService

@synthesize queue = _queue;

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self == nil)
    {
        return nil;
    }
    
    _queue = [[NSOperationQueue alloc] init];
    return self;
}

#pragma mark - Class logic

- (void)execute:(NSOperation *)operation
{
    if (operation != nil)
    {
        [self.queue addOperation:operation];
    }
}

@end
