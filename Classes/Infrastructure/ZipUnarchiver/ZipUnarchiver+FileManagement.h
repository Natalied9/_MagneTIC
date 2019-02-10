//
//  ZipUnarchiver+FileManagement.h
//

#import "ZipUnarchiver.h"

@interface ZipUnarchiver (FileManagement)

- (instancetype)initWithZipFileAtPath:(NSString *)zipFilePath;
- (void)unzipToDestinationPath:(NSString *)dstPath error:(NSError * __autoreleasing *)error;

@end
