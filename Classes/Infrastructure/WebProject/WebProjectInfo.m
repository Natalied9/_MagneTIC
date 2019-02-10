//
//  WebProjectInfo.m
//
//  Created by Sergey Seroshtan on 03.07.12.
//  Copyright (c) 2012 Exadel Inc. All rights reserved.
//

#import "WebProjectInfo.h"
#import "NSObject+Utils.h"

static NSString *const kAssetsBundleFolderName = @"www/project";
static NSString *const kAssetsWorkingFolderName = @"WebApplication";
static NSString *const kAssetsArchiveFileExtension = @"zip";
static NSString *const kDefaultStartPageName = @"index.html";

static NSString *const kAutoupdateEnabled = @"AutoupdateEnabled";
static NSString *const kAutoupdateBundleURL = @"AutoupdateBundleURL";
static NSString *const kBuildTimestamp = @"BuildTimestamp";
static NSString *const kVersionKey = @"Version";

static NSString *const kValueTrue = @"true";

#pragma mark - Private interface declaration

@interface WebProjectInfo ()

/**
 * @returns - YES if item spefified by path parameter is directory;
 *          - NO otherwise.
 * @parameter path - path to tested element.
 */
- (BOOL)isDirectory:(NSString *)path error:(NSError **)error;

/**
 * Fixes start page name if it includes double encoded URL special characters.
 *      For example index%2528.html wil be fixed to index%28.html.
 */
- (NSString *)fixStartPageName:(NSString *)baseName;

@end

#pragma mark - Public interface implementation

@implementation WebProjectInfo

@dynamic version;
@dynamic autoupdateEnabled;
@dynamic autoupdateBundleURL;
@dynamic folderPath;
@dynamic folderURL;
@dynamic startPageName;
@dynamic bundleAssetsPath;

- (NSString *)bundleAssetsPath
{
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *assetsPath = [resourcePath stringByAppendingPathComponent:kAssetsBundleFolderName];
    return (assetsPath.length > 0) ? assetsPath : kAssetsBundleFolderName;
}

#pragma mark - Properties getters implementation

- (NSDate *)version
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSObject *candidate = [defs objectForKey:kVersionKey];
    NSDate *version = [candidate as:[NSDate class]];
    
    if (version == nil)
    {
        // If there is no version in defaults database
        // it might be in info.plist (e.g. the app is launched for the first time).
        NSNumber *ts = [[[NSBundle mainBundle] objectForInfoDictionaryKey:kBuildTimestamp] as:[NSNumber class]];
        if ([ts doubleValue] > 0.0)
        {
            version = [NSDate dateWithTimeIntervalSince1970:[ts doubleValue]];
            if (version != nil)
            {
                [defs setObject:version forKey:kVersionKey];
                [defs synchronize];
            }
        }
    }
    return version;
}

- (void)setVersion:(NSString *)version
{
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if (version == nil)
    {
        // Remove version from defaults database
        [defs removeObjectForKey:kVersionKey];
    }
    else
    {
        // Set new value to defaults database
        [defs setObject:version forKey:kVersionKey];
    }
    // Commit changes.
    [defs synchronize];
}

- (NSNumber *)autoupdateEnabled
{
    NSObject *candidate = [[NSBundle mainBundle] objectForInfoDictionaryKey:kAutoupdateEnabled];
    return [candidate as:[NSNumber class]];
}

- (NSString *)autoupdateBundleURL
{
    NSObject *candidate = [[NSBundle mainBundle] objectForInfoDictionaryKey:kAutoupdateBundleURL];
    return [candidate as:[NSString class]];
}

- (NSString *)folderPath
{
    NSArray *candidates = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (0 >= [candidates count])
    {
        return nil;
    }
    
    return [[candidates[0] as:[NSString class]] stringByAppendingPathComponent:kAssetsWorkingFolderName];
}

- (NSString *)folderURL
{
    NSString *folderCandidate = [self folderPath];
    if (folderCandidate.length == 0) {
        return kAssetsBundleFolderName;
    }
    
    folderCandidate = [folderCandidate stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/ "]];
    NSString *urlCandidate = [NSString stringWithFormat:@"file:///%@", folderCandidate];
    return urlCandidate;
}

- (NSString *)startPageName
{
    return kDefaultStartPageName;
}

#pragma mark - Private interface implementation

- (BOOL)isDirectory:(NSString *)path error:(NSError **)error
{
    NSDictionary *itemAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath: path error: error];
    
    if (!*error)
    {
        return [[itemAttributes objectForKey: NSFileType] isEqualToString: NSFileTypeDirectory];
    }
    
    return NO;
}

- (NSString *)fixStartPageName:(NSString *)baseName
{
    if(baseName.length > 0)
    {
        return (NSString *) CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapes(NULL, (CFStringRef)[baseName mutableCopy], CFSTR("")));
    }
    
    return nil;
}

@end
