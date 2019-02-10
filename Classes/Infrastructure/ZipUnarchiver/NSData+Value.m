//
//  NSData+Value.m
//

#import "NSData+Value.h"

@implementation NSData (Value)

- (NSUInteger)valueWithRange:(NSRange)range {
    UInt8 buf[4] = {0};
    NSUInteger value = 0;
    
    [self getBytes:&buf range:range];
    memcpy(&value, buf, range.length);
    
    return value;
}

@end
