//
//  CentralDirectory.m
//

#import "CentralDirectory.h"
#import "NSData+Value.h"

@interface CentralDirectory ()
{
    NSUInteger _numberOfDisk;        // Number of current disk
    NSUInteger _cdStartingDisk;      // Disk, where central directory starts
    NSUInteger _countOfItemsOnDisk;  // Count of central directory records on this Disk
    NSUInteger _countOfItems;        // Count of central directory records
    NSUInteger _cdSize;              // Central directory size in bytes
    NSUInteger _cdPosition;          // Central directory position with respect to the starting disk number
    NSUInteger _zipCommentLength;    // Length of the zip-file comment in bytes
    NSString*  _zipComment;          // Zip-file comment.
}

- (NSUInteger)centralDirectoryPositionWithZipData:(NSData *)zipData;
- (NSInteger)readGlobalZipInfoWithZipData:(NSData *)zipData;

@end

@implementation CentralDirectory

@synthesize fileHeadersList = _fileHeadersList;

#pragma mark - Lifecycle

- (instancetype)initWithZipData:(NSData *)zipData {
    if (self = [super init]) {
        _zipComment = nil;
        if (zipData != nil) {
            if ([self readGlobalZipInfoWithZipData:zipData] == 0) {
                _fileHeadersList = [[NSMutableArray alloc] init];
                NSUInteger position = _cdPosition;
                for (NSUInteger i = 0; i < _countOfItems; i++) {
                    FileHeader* item = [[FileHeader alloc] initWithZipData:zipData atPosition:position];
                    if (nil == item) {
                        return nil;
                    }
                    [_fileHeadersList addObject:item];
                    position = [item offsetNextFileHeader];
                    item = nil;
                }
            }
        }
    }
    return self;
}

- (void)dealloc {
    _zipComment = nil;
    _fileHeadersList = nil;
}

#pragma mark - Private class logic

- (NSUInteger)centralDirectoryPositionWithZipData:(NSData *)zipData {
    NSUInteger cdPosition = 0;
    NSUInteger dataLength = [zipData length];
    if(0 >= dataLength) {
        return cdPosition;
    }
    
    const NSUInteger kBufferReadCount = 0x400;
    char* buf = (char*) malloc(sizeof(char) * (kBufferReadCount + 4));
    if (NULL == buf) {
        return cdPosition;
    }
    memset(buf, 0, kBufferReadCount + 4);
    
    
    NSUInteger readSize = 4;
    while (dataLength > readSize) {
        if (dataLength < readSize + kBufferReadCount) {
            readSize = dataLength;
        }
        else {
            readSize += kBufferReadCount;
        }
        
        NSUInteger readPosition = dataLength - readSize;
        NSUInteger actualSize = ( (kBufferReadCount + 4) < (dataLength - readPosition) ) ? (kBufferReadCount + 4) : dataLength - readPosition;
        
        memcpy(buf, ((char*)[zipData bytes]) + readPosition, actualSize);
        
        for (NSInteger i = (NSInteger)actualSize - 3; i > 0; i--) {
            // Search for End of central directory signature = 0x06054b50
            if ((0x50 == *(buf + i)) && (0x4b == *(buf + i + 1)) && (0x05 == *(buf + i + 2)) && (0x06 == *(buf + i + 3))) {
                cdPosition = readPosition + (NSUInteger)i;
                break;
            }
        }
        
        if (0 != cdPosition) {
            break;
        }
    }
    
    free(buf);
    return cdPosition;
}

- (NSInteger)readGlobalZipInfoWithZipData:(NSData *)zipData {
    NSUInteger cdPosition = [self centralDirectoryPositionWithZipData:zipData];
    if (0 == cdPosition) {
        return -1;
    }
    
    // Miss central directory signature. It has size of 4 bytes.
    NSUInteger offset = 4;
    NSUInteger size = 2;
    // And read number of current disk in archive.
    _numberOfDisk = [zipData valueWithRange:NSMakeRange(cdPosition + offset, size)];
    offset += size;
    
    // Read number of disk where CD starts
    _cdStartingDisk = [zipData valueWithRange:NSMakeRange(cdPosition + offset, size)];
    offset += size;
    
    // Read count of CD records on this Disk
    _countOfItemsOnDisk = [zipData valueWithRange:NSMakeRange(cdPosition + offset, size)];
    offset += size;
    
    // Read count of CD records
    _countOfItems = [zipData valueWithRange:NSMakeRange(cdPosition + offset, size)];
    offset += size;
    
    // Read size of the CD
    size = 4;
    _cdSize = [zipData valueWithRange:NSMakeRange(cdPosition + offset, size)];
    offset += size;
    
    // Read CD offset
    _cdPosition = [zipData valueWithRange:NSMakeRange(cdPosition + offset, size)];
    offset += size;
    
    // Read zip-file comment length
    size = 2;
    _zipCommentLength = [zipData valueWithRange:NSMakeRange(cdPosition + offset, size)];
    offset += size;
    
    if (0 < _zipCommentLength) {
        // If there is comment - read it
        char* zipCommentCstr = (char*) malloc(sizeof(char) * _zipCommentLength);
        NSRange filenameRange = NSMakeRange(cdPosition + offset, _zipCommentLength);
        [zipData getBytes:zipCommentCstr range:filenameRange];
        _zipComment = [[NSString alloc] initWithBytes:zipCommentCstr length:_zipCommentLength encoding:NSUTF8StringEncoding];
        free(zipCommentCstr);
    }
    return 0;
}

@end