//
//  NSDate+Dos.m
//

#import "NSDate+Dos.h"

@implementation NSDate (Dos)

+ (NSDate *)dateWithDosDate:(NSUInteger)value {
    NSCalendar* gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents* dc = [[NSDateComponents alloc] init];
    NSUInteger uDate = (NSUInteger)(value >> 16);
    dc.day = (NSInteger)(uDate & 0x1f);
    dc.month =  (NSInteger)(((uDate) & 0x1E0) / 0x20);
    dc.year = (NSInteger)(((uDate&0x0FE00) / 0x0200) + 1980);
    
    dc.hour = (NSInteger) ((value & 0xF800) / 0x800);
    dc.minute =  (NSInteger) ((value & 0x7E0) / 0x20);
    dc.second =  (NSInteger) (2 * (value & 0x1f));
    
    NSDate* date = [gregorian dateFromComponents:dc];    
    return date;
}

@end
