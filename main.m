//
//  main.m
//
//  Created by Sergey Tkachenko on 2/6/14.
//  Copyright © 2014 Exadel Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

int main(int argc, char* argv[])
{
    @autoreleasepool {
        @try {
            return UIApplicationMain(argc, argv, nil, @"ApplicationDelegate");
        } @catch (NSException *exception) {
            NSLog(@"%@", [exception reason]);
        }
    }
}
