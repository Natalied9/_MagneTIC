//
//  CentralDirectory.h
//

//  Central directory headers <FileHeader>

//  End of central directory record:
//  Offset   Length   Contents
//  0      4 bytes  End of central dir signature (0x06054b50)
//  4      2 bytes  Number of this disk
//  6      2 bytes  Number of the disk with the start of the central directory
//  8      2 bytes  Total number of entries in the central dir on this disk
//  10     2 bytes  Total number of entries in the central dir
//  12     4 bytes  Size of the central directory
//  16     4 bytes  Offset of start of central directory with respect to the starting disk number
//  20     2 bytes  zipfile comment length (c)
//  22     (c)bytes  zipfile comment

#import <Foundation/Foundation.h>
#import "FileHeader.h"

@interface CentralDirectory : NSObject

- (instancetype)initWithZipData:(NSData *)zipData NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong) NSMutableArray *fileHeadersList;

@end
