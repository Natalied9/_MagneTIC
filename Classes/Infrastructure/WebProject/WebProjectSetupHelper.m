//
//  WebProjectSetupHelper.m
//  DownloadableAssets
//
//  Created by Pavel Gorb on 8/5/15.
//
//

#import "WebProjectSetupHelper.h"
#import "WebProjectInfo.h"
#import "ZipUnarchiver.h"
#import "ZipUnarchiver+FileManagement.h"

#import "NetworkOperation.h"
#import "AssetsArchiveDownloadOperation.h"
#import "ApperyPublishingService.h"

#import "NSObject+Utils.h"
#import "WebProjectSetupHelperDelegate.h"

NSString *const kWebProjectSetupHelperErrorDomain = @"WebProjectSetupHelperErrorDomain";
const NSInteger kWebProjectSetupHelperErrorNoProjectInfo = -1000;
const NSInteger kWebProjectSetupHelperErrorImpossibleToUnarchiveAssetsFromBundle = -1010;
const NSInteger kWebProjectSetupHelperErrorNoAssetsData = -1020;
const NSInteger kWebProjectSetupHelperErrorImpossibleToUnarchiveAssets = -1030;
const NSInteger kWebProjectSetupHelperErrorUnexpectedError = -1040;
const NSInteger kWebProjectSetupHelperErrorNoConnection = -1050;

static NSString *const kCordovaLibFileName = @"cordova.js";
static NSString *const kCordovaPluginsFileName = @"cordova_plugins.js";
static NSString *const kTargetPlatformsFileName = @"get_target_platform.js";
static NSString *const kPluginsFolderName = @"plugins";

@interface WebProjectSetupHelper ()

@property (nonatomic, weak, readwrite) id<WebProjectSetupHelperDelegate> delegate;
@property (atomic, strong, readwrite) NSNumber *processing;

@property (nonatomic, strong) WebProjectInfo *projectInfo;
@property (nonatomic, strong) ApperyPublishingService *service;

- (void)setupAssetsFromBundle;
- (void)setupAssetsWithData:(NSData *)data version:(NSDate *)version;
- (void)copyItemFromPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError *__autoreleasing *)error;
- (BOOL)isProjectInDestinationDirectory;

@end

@implementation WebProjectSetupHelper

@synthesize delegate = _delegate;
@synthesize processing = _processing;
@synthesize projectInfo = _projectInfo;
@synthesize service = _service;

#pragma mark - Lifecycle

- (instancetype)initWithProjectInfo:(WebProjectInfo *)info delegate:(id<WebProjectSetupHelperDelegate>)delegate
{
    self = [super init];
    if (self == nil)
    {
        return nil;
    }
    
    _projectInfo = info;
    _delegate = delegate;
    _processing = @NO;
    return self;
}

- (instancetype)init
{
    return [self initWithProjectInfo:nil delegate:nil];
}

#pragma mark - Class logic

- (void)performSetup
{
    if (self.projectInfo == nil)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            id<WebProjectSetupHelperDelegate> del = self.delegate;
            NSError *err = [NSError errorWithDomain:kWebProjectSetupHelperErrorDomain code:kWebProjectSetupHelperErrorNoProjectInfo userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"There is no project info to setup.", @"There is no project info to setup.") }];
            [del didFinishSetupProjectWithError:err];
        });
        return;
    }
    
    self.processing = @YES;
    // If autoupdate is enabled (updateURL is given)
    if ([self.projectInfo.autoupdateEnabled boolValue] &&
        self.projectInfo.autoupdateBundleURL.length > 0)
    {
        if (self.service == nil)
        {
            self.service = [[ApperyPublishingService alloc] init];
        }
        
        [self.service downloadSingleAssetsArchiveWithUpdateURL:self.projectInfo.autoupdateBundleURL
                                                currentVersion:self.projectInfo.version
                                                 reciveHandler:^(NetworkOperation *operation) {
                                                     // All is OK. Recive responce
                                                     dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                                         id<WebProjectSetupHelperDelegate> del = self.delegate;
                                                         [del willStartCostlyAction];
                                                     });
                                                 }
                                             completionHandler:^(NetworkOperation *operation) {
            if (operation.status != Done) {
                    if (![self isProjectInDestinationDirectory])
                    {
                        // If not - just use bundle version
                        [self setupAssetsFromBundle];
                        return;
                    }
                    // All is OK. File is not moidified. Version is not updated yet.
                    // Or error downloading assets. Use downloaded version!
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        id<WebProjectSetupHelperDelegate> del = self.delegate;
                        [del willFinishCostlyAction];
                        [del didFinishSetupProjectWithError:nil];
                    });
                    self.processing = @NO;
                    return;
            }
            
            AssetsArchiveDownloadOperation* aop = [operation as:[AssetsArchiveDownloadOperation class]];
            if (aop == nil)
            {
                NSLog(@"Unexpected service request. Assets update failed. Will use default assets.");
                [self setupAssetsFromBundle];
                return;
            }
            
            // Unpack assets archive.
            [self setupAssetsWithData:aop.responseBody version:aop.publishedVersion];
        }];
    }
    else
    {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                id<WebProjectSetupHelperDelegate> del = self.delegate;
                [del didFinishSetupProjectWithError:nil];
            });
            self.processing = @NO;
    }
}

#pragma mark - Private class logic

- (void)setupAssetsFromBundle
{
    NSFileManager *localManager = [[NSFileManager alloc] init];
    NSError *error = nil;
    BOOL dir = YES;
    NSString *dstPath = self.projectInfo.folderPath;
    if ([localManager fileExistsAtPath:dstPath isDirectory:&dir]) {
        [localManager removeItemAtPath:dstPath error:&error];
        if (error != nil)
        {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                id<WebProjectSetupHelperDelegate> del = self.delegate;
                [del willFinishCostlyAction];
                [del didFinishSetupProjectWithError:error];
            });
            self.processing = @NO;
            return;
        }
    }
    
    [localManager copyItemAtPath:self.projectInfo.bundleAssetsPath toPath:self.projectInfo.folderPath error:&error];
    [self excludeAutoupdatesFromBackup];

    if (error != nil)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            id<WebProjectSetupHelperDelegate> del = self.delegate;
            [del willFinishCostlyAction];
            [del didFinishSetupProjectWithError:error];
        });
        self.processing = @NO;
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.projectInfo.version = nil; // Drop any version, we are using default one now.
        id<WebProjectSetupHelperDelegate> del = self.delegate;
        [del willFinishCostlyAction];
        [del didFinishSetupProjectWithError:nil];
    });
    self.processing = @NO;
}

- (void)excludeAutoupdatesFromBackup {
    NSError *error = nil;
    NSURL   *autoupdateFolderURL = [NSURL fileURLWithPath:self.projectInfo.folderPath];
    BOOL success = [autoupdateFolderURL setResourceValue:[NSNumber numberWithBool:YES]
                                                  forKey:NSURLIsExcludedFromBackupKey error:&error];
    if (!success)
    {
        NSLog(@"Error excluding %@ from backup %@", [autoupdateFolderURL lastPathComponent], error);
        error = nil;
    }
}

- (void)setupAssetsWithData:(NSData *)data version:(NSDate *)version
{
    if (data.length == 0) {
        NSLog(@"Unable to unarchive assets: no assets data given.");
        [self setupAssetsFromBundle];
        return;
    }
    
    ZipUnarchiver *unarchiver = [[ZipUnarchiver alloc] initWithData:data];
    if (unarchiver == nil)
    {
        NSLog(@"Unable to unarchive assets properly.");
        [self setupAssetsFromBundle];
        return;
    }
    
    NSError *unpackError = nil;
    [unarchiver unzipToDestinationPath:self.projectInfo.folderPath error:&unpackError];

//    [[NSURL fileURLWithPath:[docs stringByAppendingPathComponent:@"WebApplication"]] getResourceValue:&val forKey:NSURLIsExcludedFromBackupKey error:&error];
//    [[NSURL fileURLWithPath:[docs stringByAppendingPathComponent:@"WebApplication"]] setResourceValue:@(YES) forKey:NSURLIsExcludedFromBackupKey error:&error];

    if (unpackError != nil)
    {
        NSLog(@"Unpack assets error: %@. Will use default assets.", unpackError.localizedDescription);
        [self setupAssetsFromBundle];
        return;
    }
    
    // Zip archive is sent without specific cordova implementations.
    // Need to add them
    // JQM-based and Angular-based projects have different webProject structures
    // Path to cordova.js is different.
    
    // We need to update 4 items:
    // - cordova.js
    // - get_target_platform.js
    // - cordova_plugins.js
    // - plugins/
    
    // Main point: All these items have the same parent folder.
    // So, we'll try to find cordova.js file and take its superfolders
    // and then use these superfolders for all 4 items.
    NSString *srcFolder = self.projectInfo.bundleAssetsPath;
    NSString *dstFolder = self.projectInfo.folderPath;
    
    NSString *cordova = nil;
    NSString *workSubdir = nil;
    NSString *bundleSubdir = nil;

    NSFileManager *localManager = [[NSFileManager alloc] init];
    NSDirectoryEnumerator *workDir = [localManager enumeratorAtPath:self.projectInfo.folderPath];
    NSString *file = nil;
    while ((file = [workDir nextObject]))
    {
        if ([file rangeOfString:kCordovaLibFileName].location != NSNotFound)
        {
            cordova = file;
        }
    }
    if (cordova.length > 0)
    {
        workSubdir = [cordova stringByDeletingLastPathComponent];
        if (workSubdir == nil)
        {
            workSubdir = @"";
        }
    }
    
    cordova = nil;
    NSDirectoryEnumerator *bundleDir = [localManager enumeratorAtPath:srcFolder];
    while ((file = [bundleDir nextObject]))
    {
        if ([file rangeOfString:kCordovaLibFileName].location != NSNotFound)
        {
            cordova = file;
        }
    }
    if (cordova.length > 0)
    {
        bundleSubdir = [cordova stringByDeletingLastPathComponent];
        if (bundleSubdir == nil)
        {
            bundleSubdir = @"";
        }
    }
    
    [self excludeAutoupdatesFromBackup];
    NSError *error = nil;
    
    // Copy cordova.js
    NSString *srcEndpoint = [bundleSubdir stringByAppendingPathComponent:kCordovaLibFileName];
    NSString *destEndpoint = [workSubdir stringByAppendingPathComponent:kCordovaLibFileName];
    [self copyItemFromPath:[srcFolder stringByAppendingPathComponent:srcEndpoint] toPath:[dstFolder stringByAppendingPathComponent:destEndpoint] error:&error];
    if (error != nil)
    {
        NSLog(@"Error copying '%@' item into web application folder. Will use default assets.", kCordovaLibFileName);
        [self setupAssetsFromBundle];
        [self excludeAutoupdatesFromBackup];
        return;
    }
    // Copy cordova_plugins.js
    srcEndpoint = [bundleSubdir stringByAppendingPathComponent:kCordovaPluginsFileName];
    destEndpoint = [workSubdir stringByAppendingPathComponent:kCordovaPluginsFileName];
    [self copyItemFromPath:[srcFolder stringByAppendingPathComponent:srcEndpoint] toPath:[dstFolder stringByAppendingPathComponent:destEndpoint] error:&error];
    if (error != nil)
    {
        NSLog(@"Error copying '%@' item into web application folder. Will use default assets.", kCordovaPluginsFileName);
        [self setupAssetsFromBundle];
        [self excludeAutoupdatesFromBackup];
        return;
    }
    // Copy plugins/ folder (cordova plugins).
    srcEndpoint = [bundleSubdir stringByAppendingPathComponent:kPluginsFolderName];
    destEndpoint = [workSubdir stringByAppendingPathComponent:kPluginsFolderName];
    [self copyItemFromPath:[srcFolder stringByAppendingPathComponent:srcEndpoint] toPath:[dstFolder stringByAppendingPathComponent:destEndpoint] error:&error];
    if (error != nil)
    {
        NSLog(@"Error copying '%@' item into web application folder. Will use default assets.", kPluginsFolderName);
        [self setupAssetsFromBundle];
        return;
    }
    // Copy get_target_platforms.js
    // This file is not present in Angular-based template.
    // Because of this we should not fail in case it is absent.
    srcEndpoint = [bundleSubdir stringByAppendingPathComponent:kTargetPlatformsFileName];
    destEndpoint = [workSubdir stringByAppendingPathComponent:kTargetPlatformsFileName];
    [self copyItemFromPath:[srcFolder stringByAppendingPathComponent:srcEndpoint] toPath:[dstFolder stringByAppendingPathComponent:destEndpoint] error:&error];
    if (error != nil)
    {
        NSLog(@"Error copying '%@' item into web application folder.", kTargetPlatformsFileName);
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.projectInfo.version = version;
        id<WebProjectSetupHelperDelegate> del = self.delegate;
        [del didUpdateAssets];
        [self excludeAutoupdatesFromBackup];
        [del willFinishCostlyAction];
        [del didFinishSetupProjectWithError:unpackError];
    });
    self.processing = @NO;
}

- (void)copyItemFromPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError *__autoreleasing *)error
{
    NSFileManager *fm = [[NSFileManager alloc] init];
    if ([fm fileExistsAtPath:dstPath])
    {
        [fm removeItemAtPath:dstPath error:error];
        if (*error != nil)
        {
            return;
        }
    }
    
    [fm copyItemAtPath:srcPath toPath:dstPath error:error];
}

- (BOOL)isProjectInDestinationDirectory
{
    // Check if there is something unpacked already at the path
    NSFileManager *fm = [[NSFileManager alloc] init];
    BOOL isDir = NO;
    NSString *path = [self.projectInfo.folderPath stringByAppendingString:@"/"];
    path = [path stringByAppendingString:self.projectInfo.startPageName];
    
    return [fm fileExistsAtPath:path isDirectory:&isDir] && !isDir;
}

@end
