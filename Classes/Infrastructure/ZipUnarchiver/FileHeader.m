//
//  FileHeader.m
//

#import "FileHeader.h"
#import "NSDate+Dos.h"
#import "NSData+Value.h"

@implementation FileHeader

@synthesize madeVersion = _madeVersion;
@synthesize needVersion = _needVersion;
@synthesize flag = _flag;
@synthesize compressionMethod = _compressionMethod;
@synthesize lastModDate = _lastModDate;
@synthesize crc = _crc;
@synthesize compressedSize = _compressedSize;
@synthesize uncompressedSize = _uncompressedSize;
@synthesize nameLen = _nameLen;
@synthesize extraFieldLen = _extraFieldLen;
@synthesize fileComLen = _fileComLen;
@synthesize diskNumStart = _diskNumStart;
@synthesize internalFileAttr = _internalFileAttr;
@synthesize externalFileAttr = _externalFileAttr;
@synthesize relativeOffset = _relativeOffset;

@synthesize filename = _filename;
@synthesize extraDataRange = _extraDataRange;
@synthesize fileComment = _fileComment;

@synthesize dataRange = _dataRange;

@synthesize localFileHeader = _localFileHeader;

#pragma mark - Lifecycle

- (instancetype)init {
    return [self initWithZipData:nil atPosition:0];
}

- (instancetype)initWithZipData:(NSData *)zipData atPosition:(NSUInteger)position {
    if (self = [super init]) {
        NSUInteger dataLength = [zipData length];
        if (0 < dataLength) {
            char buf[4] = {0};
            [zipData getBytes:&buf length:4];
            [zipData getBytes:&buf range:NSMakeRange(position, 4)];
            if ((0x50 == buf[0]) && (0x4b == buf[1]) && (0x01 == buf[2]) && (0x02 == buf[3])) {
                // Miss signature. It has size of 4 bytes.
                NSUInteger size, offset = 4;
                
                //version made by
                size = 2;
                _madeVersion = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                offset += size;
                
                //version needed to extract
                _needVersion = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                offset += size;
                
                //general purpose bit flag
                _flag = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                offset += size;
                
                //compression method
                _compressionMethod = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                offset += size;
                
                //last mod file date
                size = 4;
                NSUInteger modDate = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                _lastModDate = [NSDate dateWithDosDate:modDate];
                offset += size;
                
                //crc-32
                _crc = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                offset += size;
                
                //compressed size
                _compressedSize = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                offset += size;
                
                //uncompressed size
                _uncompressedSize = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                offset += size;
                
                //file name length
                size = 2;
                _nameLen = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                offset += size;
                
                //extra field length
                _extraFieldLen = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                offset += size;
                
                //file comment length
                _fileComLen = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                offset += size;
                
                //disk number start
                _diskNumStart = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                offset += size;
                
                //internal file attributes
                _internalFileAttr = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                offset += size;
                
                //external file attributes
                size = 4;
                _externalFileAttr = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                offset += size;
                
                //relative offset of local header
                _relativeOffset = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                offset += size;
                
                //extra fields
                //file name
                char* name_str = (char*) malloc(sizeof(char) * _nameLen);
                NSRange filenameRange = NSMakeRange(position + offset, _nameLen);
                [zipData getBytes:name_str range:filenameRange];
                _filename = [[NSString alloc] initWithBytes:name_str length:_nameLen encoding:NSUTF8StringEncoding];
                free(name_str);
                
                //extra field data range
                _extraDataRange = NSMakeRange(filenameRange.location + filenameRange.length, _extraFieldLen);
                
                //file comment
                char* comment_str = (char*) malloc(sizeof(char) * _fileComLen);
                NSRange filecomentRange = NSMakeRange(_extraDataRange.location + _extraDataRange.length, _fileComLen);
                [zipData getBytes:comment_str range:filecomentRange];
                _fileComment = [[NSString alloc] initWithBytes:comment_str length:_fileComLen encoding:NSUTF8StringEncoding];
                free(comment_str);
                
                //lochal file header
                _localFileHeader = [[LocalFileHeader alloc] initWithFileHeader:self atZipData:zipData];
                
                //data range
                _dataRange = NSMakeRange([_localFileHeader offsetData], _compressedSize);
            }
        }
    }
    return self;
}

- (void)dealloc {
    _lastModDate = nil;
    _filename = nil;
    _fileComment = nil;
}

#pragma mark - Public class logic

- (NSUInteger)offsetNextFileHeader {
    return _extraDataRange.location + _extraDataRange.length + _fileComLen;
}

- (NSString *)description {
    NSString* madeVersionStr = [NSString stringWithFormat:@"\tversion made by: %lu", (unsigned long)_madeVersion];
    NSString* needVersionStr = [NSString stringWithFormat:@"\tversion needed to extract: %lu", (unsigned long)_needVersion];
    NSString* flagStr = [NSString stringWithFormat:@"\tgeneral purpose bit flag: %lx", (unsigned long)_flag];
    NSString* methodStr = [NSString stringWithFormat:@"\tcompression method: %lu", (unsigned long)_compressionMethod];
    NSString* lastModDateStr = [NSString stringWithFormat:@"\tlast mod file date: %@", _lastModDate];
    NSString* crcStr = [NSString stringWithFormat:@"\tcrc-32: %lu", (unsigned long)_crc];
    NSString* compressedSizeStr = [NSString stringWithFormat:@"\tcompressed size: %lu", (unsigned long)_compressedSize];
    NSString* uncompressedSizeStr = [NSString stringWithFormat:@"\tuncompressed size: %lu", (unsigned long)_uncompressedSize];
    NSString* nameLenStr = [NSString stringWithFormat:@"\tfile name length: %lu", (unsigned long)_nameLen];
    NSString* extraFieldLenStr = [NSString stringWithFormat:@"\textra field length: %lu", (unsigned long)_extraFieldLen];
    NSString* fileComLenStr = [NSString stringWithFormat:@"\tfile comment length: %lu", (unsigned long)_fileComLen];
    NSString* diskNumStartStr = [NSString stringWithFormat:@"\tdisk number start: %lu", (unsigned long)_diskNumStart];
    NSString* internalFileAttrStr = [NSString stringWithFormat:@"\tinternalFileAttr: %lu", (unsigned long)_internalFileAttr];
    NSString* externalFileAttrStr = [NSString stringWithFormat:@"\texternal file attributes: %lu", (unsigned long)_externalFileAttr];
    NSString* relativeOffsetStr = [NSString stringWithFormat:@"\trelative offset of local header: %lu", (unsigned long)_relativeOffset];
    
    NSString* nameStr = [NSString stringWithFormat:@"\tNAME: %@", _filename];
    NSString* extraDataRangeStr = [NSString stringWithFormat:@"\textra field data range: location: %lu length %lu", (unsigned long)_extraDataRange.location, (unsigned long)_extraDataRange.length];
    NSString* fileCommentStr = [NSString stringWithFormat:@"\tfile comment: %@", _fileComment];
    NSString* dataRangeStr = [NSString stringWithFormat:@"\tdata range: location: %lu length %lu", (unsigned long)_dataRange.location, (unsigned long)_dataRange.length];
    
    return [NSString stringWithFormat:@"\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n", madeVersionStr, needVersionStr, flagStr, methodStr, lastModDateStr, crcStr, compressedSizeStr, uncompressedSizeStr, nameLenStr, extraFieldLenStr, fileComLenStr, diskNumStartStr, internalFileAttrStr, externalFileAttrStr, relativeOffsetStr, nameStr, extraDataRangeStr, fileCommentStr, dataRangeStr];
}

@end
