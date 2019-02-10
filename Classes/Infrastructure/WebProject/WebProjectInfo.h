//
//  WebProjectInfo.h
//
//  Created by Sergey Seroshtan on 03.07.12.
//  Copyright (c) 2012 Exadel Inc. All rights reserved.
//
//  This class provides information about web project,
//      namely it folder location, start page name, etc.
//

#import <Foundation/Foundation.h>

@interface WebProjectInfo : NSObject

// Current version. 
@property (nonatomic, strong) NSDate *version;
// flag that signals autoudate is enabled or not.
@property (nonatomic, strong, readonly) NSNumber *autoupdateEnabled;
// url string for requests for update assets.
@property (nonatomic, strong, readonly) NSString *autoupdateBundleURL;
// web project folder path.
@property (nonatomic, strong, readonly) NSString *folderPath;
// web project folder url-string.
@property (nonatomic, strong, readonly) NSString *folderURL;
// start page name for web project
@property (nonatomic, strong, readonly) NSString *startPageName;
// path to folder with assets in resources' bundle
@property (nonatomic, strong, readonly) NSString *bundleAssetsPath;

@end
