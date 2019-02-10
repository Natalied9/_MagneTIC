//
//  LocalFileHeader.h
//


//  Local file header:
//  Offset Length   Contents
//  0      4 bytes  Local file header signature (0x04034b50)
//  4      2 bytes  Version needed to extract
//  6      2 bytes  General purpose bit flag
//  8      2 bytes  Compression method
//  10     2 bytes  Last mod file time
//  12     2 bytes  Last mod file date
//  14     4 bytes  CRC-32
//  18     4 bytes  Compressed size (n)
//  22     4 bytes  Uncompressed size
//  26     2 bytes  Filename length (f)
//  28     2 bytes  Extra field length (e)
//         (f)bytes  Filename
//         (e)bytes  Extra field
//         (n)bytes  Compressed data

//  Extended local header:
//  Offset   Length   Contents
//  0      4 bytes  Extended Local file header signature (0x08074b50)
//  4      4 bytes  CRC-32
//  8      4 bytes  Compressed size
//  12     4 bytes  Uncompressed size

#import <Foundation/Foundation.h>

@class FileHeader;

@interface LocalFileHeader : NSObject   // 0x04034b50

- (instancetype)initWithFileHeader:(FileHeader *)fh atZipData:(NSData *)zipData;
- (NSUInteger)offsetData;

@property (nonatomic, assign, readonly) FileHeader *fileheader;

//  Local file header:
@property (nonatomic, assign) NSUInteger needVersion;       //version needed to extract
@property (nonatomic, assign) NSUInteger flag;              //general purpose bit flag
@property (nonatomic, assign) NSUInteger compressionMethod; //compression method
@property (nonatomic, strong) NSDate *lastModDate;          //last mod file date
@property (nonatomic, assign) NSUInteger crc;               //crc-32
@property (nonatomic, assign) NSUInteger compressedSize;    //compressed size
@property (nonatomic, assign) NSUInteger uncompressedSize;  //uncompressed size
@property (nonatomic, assign) NSUInteger nameLen;           //file name length
@property (nonatomic, assign) NSUInteger extraFieldLen;     //extra field length

@property (nonatomic, copy) NSString* filename;             //file name
@property (nonatomic, assign) NSRange extraDataRange;       //extra field data range

//  Extended local header:
@property (nonatomic, assign) NSUInteger exCrc;             //crc-32
@property (nonatomic, assign) NSUInteger exCompressedSize;  //compressed size
@property (nonatomic, assign) NSUInteger exUncompressedSize;//uncompressed size

@end
