//
//  PushNotification.m
//
// Created by Olivier Louvignes on 2012-05-06.
// Inspired by Urban Airship Inc orphaned PushNotification phonegap plugin.
//
// Copyright 2012 Olivier Louvignes. All rights reserved.
// MIT Licensed

#import "PushNotification.h"
#import <Cordova/CDVDebug.h>

@implementation PushNotification

@synthesize callbackIds = _callbackIds;
@synthesize pendingNotifications = _pendingNotifications;

- (NSMutableDictionary*)callbackIds
{
    if(_callbackIds == nil) {
        _callbackIds = [[NSMutableDictionary alloc] init];
    }
    
    return _callbackIds;
}

- (NSMutableArray*)pendingNotifications
{
    if(_pendingNotifications == nil) {
        _pendingNotifications = [[NSMutableArray alloc] init];
    }
    
    return _pendingNotifications;
}

- (void)registerDevice:(CDVInvokedUrlCommand *)command
{
    DLog(@"registerDevice:%@", command);

    // The first argument in the arguments parameter is the callbackID.
    [self.callbackIds setValue:command.callbackId forKey:@"registerDevice"];
    NSDictionary *options = [command.arguments objectAtIndex:0];

    UIRemoteNotificationType notificationTypes = UIRemoteNotificationTypeNone;
    if ([options objectForKey:@"badge"]) {
        notificationTypes |= UIRemoteNotificationTypeBadge;
    }
    if ([options objectForKey:@"sound"]) {
        notificationTypes |= UIRemoteNotificationTypeSound;
    }
    if ([options objectForKey:@"alert"]) {
        notificationTypes |= UIRemoteNotificationTypeAlert;
    }

    if (notificationTypes == UIRemoteNotificationTypeNone)
        NSLog(@"PushNotification.registerDevice: Push notification type is set to none");

    if ([[UIApplication sharedApplication] respondsToSelector:@selector(isRegisteredForRemoteNotifications)])
    {
        // iOS 8 Notifications
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationType)notificationTypes categories:nil]];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }
    else
    {
        // iOS < 8 Notifications
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:notificationTypes];
    }
}

- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    DLog(@"didRegisterForRemoteNotificationsWithDeviceToken:%@", deviceToken);

    NSString *token = [[[[deviceToken description] stringByReplacingOccurrencesOfString:@"<"withString:@""]
            stringByReplacingOccurrencesOfString:@">" withString:@""]
             stringByReplacingOccurrencesOfString: @" " withString: @""];

    NSMutableDictionary *results = [PushNotification getRemoteNotificationStatus];
    [results setValue:token forKey:@"deviceToken"];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:results];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:[self.callbackIds valueForKey:@"registerDevice"]];
}

- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
    ALog(@"didFailToRegisterForRemoteNotificationsWithError:%@", error);

    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    [results setValue:[NSString stringWithFormat:@"%@", error] forKey:@"error"];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:results];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:[self.callbackIds valueForKey:@"registerDevice"]];
}

- (void)didReceiveRemoteNotification:(NSDictionary*)userInfo
{
    DLog(@"didReceiveRemoteNotification:%@", userInfo);

    // Converting Dict to NSString in JSON format using NSJSONSerialization as per Cordova 2.4.0
    NSError* error = nil;
    NSString *jsStatement = nil;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userInfo options:0 error: &error];
    if (error != nil){
        jsStatement = [NSString stringWithFormat:@"PushNotification.notificationCallback({error: %@});",[error localizedDescription]];
    }else{
        jsStatement = [NSString stringWithFormat:@"PushNotification.notificationCallback(%@);", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]];
    }

    [self.commandDelegate evalJs:jsStatement];
}

- (void)getPendingNotifications:(CDVInvokedUrlCommand *)command
{
    DLog(@"getPendingNotifications:%@", command);

    // The first argument in the arguments parameter is the callbackID.
    [self.callbackIds setValue:command.callbackId forKey:@"getPendingNotifications"];
    //NSDictionary *options = [command.arguments objectAtIndex:0];

    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    [results setValue:self.pendingNotifications forKey:@"notifications"];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:results];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:[self.callbackIds valueForKey:@"getPendingNotifications"]];

    [self.pendingNotifications removeAllObjects];
}

+ (NSMutableDictionary*)getRemoteNotificationStatus
{
    NSMutableDictionary *results = [NSMutableDictionary dictionary];

    NSUInteger type = 0;
    // Set the defaults to disabled unless we find otherwise...
    NSString *pushBadge = @"0";
    NSString *pushAlert = @"0";
    NSString *pushSound = @"0";

    #if !TARGET_IPHONE_SIMULATOR

    // Check what Notifications the user has turned on.  We registered for all three, but they may have manually disabled some or all of them.
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(isRegisteredForRemoteNotifications)])
    {
        // iOS 8 Notifications
        UIUserNotificationSettings *currentNotifSettings = [UIApplication sharedApplication].currentUserNotificationSettings;
        type = currentNotifSettings.types;
        if (type == 0) {
            type = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
        }
    }
    else
    {
        // iOS < 8 Notifications
        type = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
    }
    // Check what Registered Types are turned on. This is a bit tricky since if two are enabled, and one is off, it will return a number 2... not telling you which
    // one is actually disabled. So we are literally checking to see if rnTypes matches what is turned on, instead of by number. The "tricky" part is that the
    // single notification types will only match if they are the ONLY one enabled.  Likewise, when we are checking for a pair of notifications, it will only be
    // true if those two notifications are on.  This is why the code is written this way
    if(type == UIRemoteNotificationTypeBadge) {
        pushBadge = @"1";
    }
    else if(type == UIRemoteNotificationTypeAlert) {
        pushAlert = @"1";
    }
    else if(type == UIRemoteNotificationTypeSound) {
        pushSound = @"1";
    }
    else if(type == ( UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert)) {
        pushBadge = @"1";
        pushAlert = @"1";
    }
    else if(type == ( UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)) {
        pushBadge = @"1";
        pushSound = @"1";
    }
    else if(type == ( UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound)) {
        pushAlert = @"1";
        pushSound = @"1";
    }
    else if(type == ( UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound)) {
        pushBadge = @"1";
        pushAlert = @"1";
        pushSound = @"1";
    }

    #endif

    // Affect results
    [results setValue:[NSString stringWithFormat:@"%lu", (unsigned long)type] forKey:@"type"];
    [results setValue:[NSString stringWithFormat:@"%d", type != UIRemoteNotificationTypeNone] forKey:@"enabled"];
    [results setValue:pushBadge forKey:@"pushBadge"];
    [results setValue:pushAlert forKey:@"pushAlert"];
    [results setValue:pushSound forKey:@"pushSound"];

    return results;
}

- (void)getRemoteNotificationStatus:(CDVInvokedUrlCommand *)command
{
    DLog(@"getRemoteNotificationStatus:%@", command);

    // The first argument in the arguments parameter is the callbackID.
    [self.callbackIds setValue:command.callbackId forKey:@"getRemoteNotificationStatus"];
    //NSDictionary *options = [command.arguments objectAtIndex:0];

    NSMutableDictionary *results = [PushNotification getRemoteNotificationStatus];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:results];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:[self.callbackIds valueForKey:@"getRemoteNotificationStatus"]];
}

- (void)getApplicationIconBadgeNumber:(CDVInvokedUrlCommand *)command
{
    DLog(@"getApplicationIconBadgeNumber:%@", command);

    [self.callbackIds setValue:command.callbackId forKey:@"getApplicationIconBadgeNumber"];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:(int)[UIApplication sharedApplication].applicationIconBadgeNumber];


    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setApplicationIconBadgeNumber:(CDVInvokedUrlCommand *)command
{
    DLog(@"setApplicationIconBadgeNumber:%@", command);

    // The first argument in the arguments parameter is the callbackID.
    [self.callbackIds setValue:command.callbackId forKey:@"setApplicationIconBadgeNumber"];
    int badge = [[[command.arguments objectAtIndex:0] objectForKey:@"badge"] intValue] ?: 0;
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:badge];

    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    [results setValue:[NSNumber numberWithInt:badge] forKey:@"badge"];
    [results setValue:[NSNumber numberWithInt:1] forKey:@"success"];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:results];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:[self.callbackIds valueForKey:@"setApplicationIconBadgeNumber"]];
}

- (void)cancelAllLocalNotifications:(CDVInvokedUrlCommand *)command
{
    DLog(@"cancelAllLocalNotifications:%@", command);

    // The first argument in the arguments parameter is the callbackID.
    [self.callbackIds setValue:command.callbackId forKey:@"cancelAllLocalNotifications"];
    //NSDictionary *options = [command.arguments objectAtIndex:0];

    [[UIApplication sharedApplication] cancelAllLocalNotifications];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:[self.callbackIds valueForKey:@"cancelAllLocalNotifications"]];
}

- (void)getDeviceUniqueIdentifier:(CDVInvokedUrlCommand *)command
{
    DLog(@"getDeviceUniqueIdentifier:%@", command);

    // The first argument in the arguments parameter is the callbackID.
    [self.callbackIds setValue:command.callbackId forKey:@"getDeviceUniqueIdentifier"];
    //NSDictionary *options = [command.arguments objectAtIndex:0];

    NSString* uuid = @"";
    if ([[UIDevice currentDevice] respondsToSelector:@selector(identifierForVendor)]) {
    // IOS 6 new Unique Identifier implementation
    uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:uuid];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:[self.callbackIds valueForKey:@"getDeviceUniqueIdentifier"]];
}

@end
