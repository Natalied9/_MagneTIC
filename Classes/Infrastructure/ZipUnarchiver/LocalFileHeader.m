//
//  LocalFileHeader.m
//

#import "LocalFileHeader.h"
#import "FileHeader.h"
#import "NSDate+Dos.h"
#import "NSData+Value.h"

@implementation LocalFileHeader

@synthesize fileheader = _fileheader;

@synthesize needVersion = _needVersion;
@synthesize flag = _flag;
@synthesize compressionMethod = _compressionMethod;
@synthesize lastModDate = _lastModDate;
@synthesize crc = _crc;
@synthesize compressedSize = _compressedSize;
@synthesize uncompressedSize = _uncompressedSize;
@synthesize nameLen = _nameLen;
@synthesize extraFieldLen = _extraFieldLen;

@synthesize filename = _filename;
@synthesize extraDataRange = _extraDataRange;

@synthesize exCrc = _exCrc;
@synthesize exCompressedSize = _exCompressedSize;
@synthesize exUncompressedSize = _exUncompressedSize;

#pragma mark - Lifecycle

- (instancetype)init {
    return [self initWithFileHeader:nil atZipData:nil];
}

- (instancetype)initWithFileHeader:(FileHeader *)fh atZipData:(NSData *)zipData {
    if (self = [super init]) {
        NSUInteger dataLength = [zipData length];
        if (0 < dataLength && (nil != fh)) {
            char buf[4] = {0};
            [zipData getBytes:&buf length:4];
            NSUInteger position = fh.relativeOffset;
            [zipData getBytes:&buf range:NSMakeRange(position, 4)];
            if ((0x50 == buf[0]) && (0x4b == buf[1]) && (0x03 == buf[2]) && (0x04 == buf[3])) {
                // Miss signature. It has size of 4 bytes.
                NSUInteger size, offset = 4;
                
                //version needed to extract
                size = 2;
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
                
                //extra fields
                //file name
                char* name_str = (char*) malloc(sizeof(char) * _nameLen);
                NSRange filenameRange = NSMakeRange(position + offset, _nameLen);
                [zipData getBytes:name_str range:filenameRange];
                _filename = [[NSString alloc] initWithBytes:name_str length:_nameLen encoding:NSUTF8StringEncoding];
                free(name_str);
                
                //extra field data range
                _extraDataRange = NSMakeRange(filenameRange.location + filenameRange.length, _extraFieldLen);
                
                //Extended local header
                if (_flag & 0x00000008) {
                    position = _extraDataRange.location + _extraDataRange.length + fh.compressedSize;
                    NSRange range = NSMakeRange(position, 4);
                    [zipData getBytes:&buf range:range];
                    if ((0x50 == buf[0]) && (0x4b == buf[1]) && (0x07 == buf[2]) && (0x08 == buf[3])) {
                        // Miss signature. It has size of 4 bytes.
                        offset = 4;
                        size = 4;
                        
                        //crc-32
                        _exCrc = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                        
                        //compressed size
                        offset += size;
                        _exCrc = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                        
                        //uncompressed size
                        offset += size;
                        _exCrc = [zipData valueWithRange:NSMakeRange(position + offset, size)];
                    }
                }
            }
        }
    }
    return self;
}

- (void)dealloc {
    _lastModDate = nil;
    _filename = nil;
}

#pragma mark - Public class logic

- (NSUInteger)offsetData {
    return _extraDataRange.location + _extraDataRange.length;
}

- (NSString *)description {
    NSString* versionStr = [NSString stringWithFormat:@"\tversion needed to extract: %lu", (unsigned long)_needVersion];
    NSString* flagStr = [NSString stringWithFormat:@"\tgeneral purpose bit flag: %lx", (unsigned long)_flag];
    NSString* methodStr = [NSString stringWithFormat:@"\tcompression method: %lu", (unsigned long)_compressionMethod];
    NSString* lastModDateStr = [NSString stringWithFormat:@"\tlast mod file date: %@", _lastModDate];
    NSString* crcStr = [NSString stringWithFormat:@"\tcrc-32: %lu", (unsigned long)_crc];
    NSString* compressedSizeStr = [NSString stringWithFormat:@"\tcompressed size: %lu", (unsigned long)_compressedSize];
    NSString* uncompressedSizeStr = [NSString stringWithFormat:@"\tuncompressed size: %lu", (unsigned long)_uncompressedSize];
    NSString* nameLenStr = [NSString stringWithFormat:@"\tfile name length: %lu", (unsigned long)_nameLen];
    NSString* extraFieldLenStr = [NSString stringWithFormat:@"\textra field length: %lu", (unsigned long)_extraFieldLen];
    
    NSString* nameStr = [NSString stringWithFormat:@"\tNAME: %@", _filename];
    NSString* extraDataRangeStr = [NSString stringWithFormat:@"\textra field data range: location: %lu length %lu", (unsigned long)_extraDataRange.location, (unsigned long)_extraDataRange.length];
    
    NSString* exCrcStr = [NSString stringWithFormat:@"\tcrc-32: %lu", (unsigned long)_exCrc];
    NSString* exCompressedSizeStr = [NSString stringWithFormat:@"\tcompressed size: %lu", (unsigned long)_exCompressedSize];
    NSString* exUncompressedSizeStr = [NSString stringWithFormat:@"\tuncompressed size: %lu", (unsigned long)_exUncompressedSize];
    NSString* exlochalHeader = [NSString stringWithFormat:@"\t\nExtended local header:\n\t%@\n\t%@\n\t%@\n", exCrcStr, exCompressedSizeStr, exUncompressedSizeStr];
    
    return [NSString stringWithFormat:@"\nLocal file header:\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n", versionStr, flagStr, methodStr, lastModDateStr, crcStr, compressedSizeStr, uncompressedSizeStr, nameLenStr, extraFieldLenStr, nameStr, extraDataRangeStr, (_flag & 0x00000008) ? exlochalHeader : @""];
}

@end