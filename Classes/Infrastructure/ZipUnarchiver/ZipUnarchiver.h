//
//  ZipUnarchiver.h
//

#import <Foundation/Foundation.h>

@protocol ZipUnarchiverErrorDelegate <NSObject>

@optional
- (void)errorMessage:(NSString *)msg;

@end

@interface Node : NSObject

- (instancetype)initWithName:(NSString *)name;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSUInteger index;
@property (nonatomic, strong) NSMutableArray *children;

@end

@interface ZipUnarchiver : NSObject

@property (nonatomic, strong, readonly) NSData *zipData;
@property (nonatomic, assign) id<ZipUnarchiverErrorDelegate> errorDelegate;

- (instancetype)initWithData:(NSData *)data NS_DESIGNATED_INITIALIZER;
- (NSArray *)archiverFileStructure;
- (NSData *)fileDataWitnIndex:(NSUInteger)fileindex;

@end
