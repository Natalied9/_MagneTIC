//
//  FileHeader.h
//


//  Header from Central directory:
//  Offset Length   Contents
//  0      4 bytes  Central file header signature (0x02014b50)
//  4      2 bytes  Version made by
//  6      2 bytes  Version needed to extract
//  8      2 bytes  General purpose bit flag
//  10     2 bytes  Compression method
//  12     2 bytes  Last mod file time
//  14     2 bytes  Last mod file date
//  16     4 bytes  CRC-32
//  20     4 bytes  Compressed size
//  24     4 bytes  Uncompressed size
//  28     2 bytes  Filename length (f)
//  30     2 bytes  Extra field length (e)
//  32     2 bytes  File comment length (c)
//  34     2 bytes  Disk number start
//  36     2 bytes  Internal file attributes
//  38     4 bytes  External file attributes
//  42     4 bytes  Relative offset of local header
//  46     (f)bytes Filename
//         (e)bytes Extra field
//         (c)bytes File comment

#import <Foundation/Foundation.h>
#import "LocalFileHeader.h"

@interface FileHeader : NSObject // 0x02014b50

- (instancetype)initWithZipData:(NSData *)zipData atPosition:(NSUInteger)position NS_DESIGNATED_INITIALIZER;
- (NSUInteger)offsetNextFileHeader;

@property (nonatomic, assign) NSUInteger madeVersion;       //version made by
@property (nonatomic, assign) NSUInteger needVersion;       //version needed to extract
@property (nonatomic, assign) NSUInteger flag;              //general purpose bit flag
@property (nonatomic, assign) NSUInteger compressionMethod; //compression method
@property (nonatomic, strong) NSDate *lastModDate;          //last mod file date
@property (nonatomic, assign) NSUInteger crc;               //crc-32
@property (nonatomic, assign) NSUInteger compressedSize;  //compressed size
@property (nonatomic, assign) NSUInteger uncompressedSize;  //uncompressed size
@property (nonatomic, assign) NSUInteger nameLen;           //file name length
@property (nonatomic, assign) NSUInteger extraFieldLen;     //extra field length
@property (nonatomic, assign) NSUInteger fileComLen;        //file comment length
@property (nonatomic, assign) NSUInteger diskNumStart;      //disk number start
@property (nonatomic, assign) NSUInteger internalFileAttr;  //internal file attributes
@property (nonatomic, assign) NSUInteger externalFileAttr;  //external file attributes
@property (nonatomic, assign) NSUInteger relativeOffset;    //relative offset of local header

@property (nonatomic, copy) NSString *filename;             //file name
@property (nonatomic, assign) NSRange extraDataRange;       //extra field data range
@property (nonatomic, copy) NSString *fileComment;          //file comment

@property (nonatomic, assign) NSRange dataRange;            //data range

@property (nonatomic, strong) LocalFileHeader *localFileHeader;

@end
