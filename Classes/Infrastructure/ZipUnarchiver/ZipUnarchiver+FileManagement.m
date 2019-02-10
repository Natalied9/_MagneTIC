//
//  ZipUnarchiver+FileManagement.m
//

#import "ZipUnarchiver+FileManagement.h"

@interface ZipUnarchiver (FileManagementHelper)

- (void)unarchiveNode:(Node *)node atPath:(NSString *)path error:(NSError * __autoreleasing *)error;

@end

@implementation ZipUnarchiver (FileManagement)

- (instancetype) initWithZipFileAtPath:(NSString *)zipFilePath;
{
    if (0 >= [zipFilePath length]) {
        return nil;
    }
    
    BOOL dir = YES;
    if (![[NSFileManager defaultManager] fileExistsAtPath:zipFilePath isDirectory:&dir] || dir) {
        return nil;
    }
    
    NSData* zipData = [NSData dataWithContentsOfFile:zipFilePath];
    return [self initWithData:zipData];
}

- (void)unzipToDestinationPath:(NSString *)dstPath error:(NSError * __autoreleasing *)error {
    if (0 >= [dstPath length]) {
        // It is no correct dst path present.
        *error = [NSError errorWithDomain:@"ZipUnarchiverErrorDomain" code:-999 userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Path for unarchiving is incorrect.", @"Path for unarchiving is incorrect.") }];
        return;
    }
    
    BOOL dir = YES;
    if ([[NSFileManager defaultManager] fileExistsAtPath:dstPath isDirectory:&dir]) {
        [[NSFileManager defaultManager] removeItemAtPath:dstPath error:error];
        if (nil != *error) {
            return;
        }
    }
    
    [[NSFileManager defaultManager] createDirectoryAtPath:dstPath withIntermediateDirectories:YES attributes:nil error:error];
    if (nil != *error) {
        return;
    }
    
    NSArray *structure = [self archiverFileStructure];
    for (Node *node in structure) {
        [self unarchiveNode:node atPath:[dstPath stringByAppendingPathComponent:[node name]] error:error];
        if (nil != *error) {
            // If there was an error during unzipping
            // Try to remove all unzipped data (clear)
            [[NSFileManager defaultManager] removeItemAtPath:dstPath error:nil];
            // And return.
            return;
        }
    }
}

#pragma mark - Private class logic

- (void)unarchiveNode:(Node *)node atPath:(NSString *)path error:(NSError * __autoreleasing *)error {
    if (0 >= [node children]) {
        // File.
        NSData* fileData = [self fileDataWitnIndex:[node index]];
        [[NSFileManager defaultManager] createFileAtPath:path contents:fileData attributes:nil];
    }
    else {
        // Folder
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error];
        if (nil != *error) {
            return;
        }
        for (Node* n in [node children]) {
            [self unarchiveNode:n atPath:[path stringByAppendingPathComponent:[n name]] error:error];
            if (nil != *error) {
                return;
            }
        }
    }
}

@end
