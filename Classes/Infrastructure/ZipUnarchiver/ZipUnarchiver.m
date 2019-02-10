//
//  ZipUnarchiver.m
//

#import "ZipUnarchiver.h"
#import "CentralDirectory.h"
#import "zlib.h"

#define BUFSIZE (16384)
#define PARAMERROR (-101)
#define BADZIPFILE (-102)
#define CRCERROR (-103)

@implementation Node

@synthesize name = _name;
@synthesize index = _index;
@synthesize children = _children;

- (instancetype)init {
    return [self initWithName:nil];
}

- (instancetype)initWithName:(NSString *)name {
    if (self = [super init]) {
        _index = NSNotFound;
        _name = [name copy];
    }
    return self;
}

- (void)dealloc {
    _name = nil;
    _children = nil;
}

@end

@interface ZipUnarchiver () {
    char *_zipDataBuf;
    
    char *_readBuffer;                   // internal buffer for compressed data
    BOOL _streamInitialised;             // flag set if stream structure is initialised
    z_stream _stream;                    // zLib stream structure for inflate
    NSUInteger _posInZipfile;            // position in byte on the zipfile, for fseek
    NSUInteger _crc32;                   // crc32 of all data uncompressed
    NSUInteger _crc32Wait;               // crc32 we must obtain after decompress all
    NSUInteger _restReadCompressed;            // number of byte to be decompressed
    NSUInteger _restReadUncompressed;          // number of byte to be obtained after decomp
    NSInteger  _raw;
}

@property (strong) NSData *zipData;
@property (atomic, strong) CentralDirectory *centralDirectory;

- (NSInteger)openCurrentFile:(FileHeader *)header raw:(NSInteger)raw;
- (NSInteger)readFileTo:(void *)buf inHeader:(FileHeader *)header length:(NSUInteger)len;
- (NSInteger)closeCurrentFile;

- (void)createItemInHierarchy:(NSMutableArray *)structure forComponentIn:(NSMutableArray *)components indexInCentralDirectory:(NSUInteger)index;
- (void)outputErrorMessage:(NSString *)msg;

@end

@implementation ZipUnarchiver

@synthesize zipData = _zipData;
@synthesize errorDelegate = _errorDelegate;
@synthesize centralDirectory = _centralDirectory;

#pragma mark - Lifecycle

- (instancetype)init {
    return [self initWithData:nil];
}

- (instancetype)initWithData:(NSData *)data {
    self = [super init];
    if (nil == self) {
        return nil;
    }
    
    _zipData = data;
    _zipDataBuf = (char *)[_zipData bytes];
    _centralDirectory = [[CentralDirectory alloc] initWithZipData:_zipData];
    
    return self;
}

- (void)dealloc {
    _zipData = nil;
}

#pragma mark - Public class logic

- (NSArray *)archiverFileStructure {
    NSMutableArray *fileStructure = [[NSMutableArray alloc] init];
    if ([_centralDirectory fileHeadersList] != nil) {
        for (NSUInteger i = 0; i < [[_centralDirectory fileHeadersList] count]; i++) {
            FileHeader *fh = [[_centralDirectory fileHeadersList] objectAtIndex:i];
            NSMutableArray *components = [[NSMutableArray alloc] initWithArray:[fh.filename componentsSeparatedByString:@"/"]];
            [self createItemInHierarchy:fileStructure forComponentIn:components indexInCentralDirectory:i];
        }
    }
    else {
        [self outputErrorMessage:@"Incorrect zip structure."];
    }
    
    return fileStructure;
}

- (NSData *)fileDataWitnIndex:(NSUInteger)fileindex
{
    NSMutableData *filedata = nil;
    if ((fileindex != NSNotFound) && (fileindex < [[_centralDirectory fileHeadersList] count])) {
        FileHeader *header = [[_centralDirectory fileHeadersList] objectAtIndex:(NSUInteger)fileindex];
        if ([self openCurrentFile:header raw:0] == Z_OK) {
            NSInteger read = 0;
            unsigned char buffer[4096];
            filedata = [[NSMutableData alloc] init];
            
            while (header != nil) {
                read = [self readFileTo:buffer inHeader:header length:4096];
                if (read > 0) {
                    [filedata appendBytes:buffer length:(NSUInteger)read];
                }
                else if (read < 0) {
                    [self outputErrorMessage:@"Failed to read zip-file structure."];
                    break;
                }
                else {
                    break;
                }
            }
        }
        else {
            [self outputErrorMessage:@"Error opening zip-file."];
        }
        
        if ([self closeCurrentFile] != Z_OK) {
            [self outputErrorMessage:@"Crc error."];
        }
    }
    
    return filedata;
}

#pragma mark - Private class logic

- (NSInteger)openCurrentFile:(FileHeader *)header raw:(NSInteger)raw {
    NSInteger err = Z_OK;
    
    _readBuffer = (char *)malloc(BUFSIZE);
    _raw = raw;
    _streamInitialised = NO;
    
    if ((header.compressionMethod != 0) && (header.compressionMethod != Z_DEFLATED)) {
        return BADZIPFILE;
    }
    
    _crc32Wait = header.crc;
    _crc32 = 0;
    _stream.total_out = 0;
    
    if ((header.compressionMethod == Z_DEFLATED) && (!raw)) {
        _stream.zalloc = (alloc_func)0;
        _stream.zfree = (free_func)0;
        _stream.opaque = (voidpf)0;
        _stream.next_in = (voidpf)0;
        _stream.avail_in = 0;
        
        err = inflateInit2(&_stream, - MAX_WBITS);
        
        if (err == Z_OK) {
            _streamInitialised = YES;
        }
        else {
            return err;
        }
    }
    _restReadCompressed = header.compressedSize;
    _restReadUncompressed = header.uncompressedSize;
    _posInZipfile = header.dataRange.location;
    _stream.avail_in = 0;
    
    return Z_OK;
}

- (NSInteger)readFileTo:(void *)buf inHeader:(FileHeader *)header length:(NSUInteger)len {
    NSInteger err = Z_OK;
    uInt iRead = 0;

    if (header == nil) {
        return PARAMERROR;
    }
    
    if (len == 0) {
        return 0;
    }
    
    _stream.next_out = (Bytef*)buf;
    _stream.avail_out = (uInt)len;
    
    if ((len > _restReadUncompressed) && (!(_raw))) {
        _stream.avail_out = (uInt)_restReadUncompressed;
    }
    
    if ((len > _restReadCompressed + _stream.avail_in) && (_raw)) {
        _stream.avail_out = (uInt)_restReadCompressed + _stream.avail_in;
    }
    
    while (_stream.avail_out > 0) {
        if ((_stream.avail_in == 0) && (_restReadCompressed > 0)) {
            uInt uReadThis = BUFSIZE;
            if (_restReadCompressed < uReadThis) {
                uReadThis = (uInt)_restReadCompressed;
            }
            
            if (uReadThis == 0) {
                return EOF;
            }
            
            memcpy(_readBuffer, _zipDataBuf + _posInZipfile, uReadThis);
            
            _posInZipfile += uReadThis;
            _restReadCompressed -= uReadThis;
            _stream.next_in = (Bytef*)_readBuffer;
            _stream.avail_in = (uInt)uReadThis;
        }
        
        if ((header.compressionMethod == 0) || (_raw)) {
            uInt uDoCopy, i;
            if ((_stream.avail_in == 0) && (_restReadCompressed == 0)) {
                return ( iRead==0 ) ? EOF : (NSInteger)iRead;
            }
            
            if (_stream.avail_out < _stream.avail_in) {
                uDoCopy = _stream.avail_out;
            }
            else {
                uDoCopy = _stream.avail_in;
            }

            for (i = 0; i < uDoCopy; i++) {
                *(_stream.next_out + i) = *(_stream.next_in + i);
            }

            _crc32 = crc32(_crc32, _stream.next_out, uDoCopy);
            _restReadUncompressed -= uDoCopy;
            _stream.avail_in -= uDoCopy;
            _stream.avail_out -= uDoCopy;
            _stream.next_out += uDoCopy;
            _stream.next_in += uDoCopy;
            _stream.total_out += uDoCopy;
            
            iRead += uDoCopy;
        }
        else {
            uLong uTotalOutBefore,uTotalOutAfter;
            const Bytef *bufBefore;
            uLong uOutThis;
            int flush = Z_SYNC_FLUSH;
            
            uTotalOutBefore = _stream.total_out;
            bufBefore = _stream.next_out;
            
            err = inflate(&_stream, flush);
            
            if ((err >= 0) && (_stream.msg != NULL)) {
                err = Z_DATA_ERROR;
            }
            
            uTotalOutAfter = _stream.total_out;
            uOutThis = uTotalOutAfter - uTotalOutBefore;
            
            _crc32 = crc32(_crc32, bufBefore, (uInt)(uOutThis));
            
            _restReadUncompressed -= uOutThis;
            
            iRead += (uInt)(uTotalOutAfter - uTotalOutBefore);
            
            if (err == Z_STREAM_END) {
                return (iRead == 0) ? EOF : (NSInteger)iRead;
            }
            if (err != Z_OK) {
                break;
            }
        }
    }
    
    if (err == Z_OK) {
        return (NSInteger)iRead;
    }
    
    return err;
}

- (NSInteger)closeCurrentFile {
    NSInteger err = Z_OK;
    
    if ((_restReadUncompressed == 0) && (!_raw)) {
        if (_crc32 != _crc32Wait) {
            err = CRCERROR;
        }
    }
    
    free(_readBuffer);
    _readBuffer = NULL;
    
    if (_streamInitialised) {
        inflateEnd(&_stream);
    }
    _streamInitialised = NO;
    
    return err;
}

- (void)createItemInHierarchy:(NSMutableArray *)structure forComponentIn:(NSMutableArray *)components indexInCentralDirectory:(NSUInteger)index {
    NSString *com = [components objectAtIndex:0];
    if ([com isEqualToString:@""]) {
        return;
    }
    
    NSUInteger indexComponent = NSNotFound;
    for (NSUInteger i = 0; i < [structure count]; i++) {
        if ([com isEqualToString:[[structure objectAtIndex:i] name]]) {
            indexComponent = i;
        }
    }
    
    if (indexComponent != NSNotFound) {
        [components removeObjectAtIndex:0];
        [self createItemInHierarchy:[[structure objectAtIndex:indexComponent] children] forComponentIn:components indexInCentralDirectory:index];
    }
    else {
        if ([components count] >= 2) {
            //folder
            Node *node = [[Node alloc] initWithName:com];
            NSMutableArray *child = [[NSMutableArray alloc] init];
            node.children = child;
            node.index = index;
            
            [structure addObject:node];
            [components removeObjectAtIndex:0];
            
            [self createItemInHierarchy:child forComponentIn:components indexInCentralDirectory:index];
        }
        else {
            //file
            Node *node = [[Node alloc] initWithName:com];
            node.index = index;
            [structure addObject:node];
        }
    }
}

- (void)outputErrorMessage:(NSString *)msg {
    if ([_errorDelegate respondsToSelector:@selector(errorMessage:)]) {
		[_errorDelegate errorMessage:msg];
    }
}

@end