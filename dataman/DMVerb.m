//
//  Verb.m
//  dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 FSDEV. All rights reserved.
//

#import "DMVerb.h"

#import "Console.h"

#import "NDService.h"

// remember to update the manpage if these change
NSString* kConfigDefault   = @"~/.dataman.plist";
NSString* kConfigServerURL = @"server"          ;
NSString* kConfigAPIKey    = @"apikey"          ;
NSString* kConfigUsername  = @"username"        ;
NSString* kConfigPassword  = @"password"        ;

NSString* kFlagServerConfig = @"-f";
NSString* kFlagServerConfigLong = @"--server-config";

@interface DMVerb (__private__)

- (void)obtainConfig;

@end

@implementation DMVerb

@synthesize arguments = _arguments;
@synthesize service = _service;
@synthesize configuration = _configuration;

- (void)run
{
    /*
     global:
        optional args:
            -c --server-config FILE session config file (use default location if an explicit location is not set)
     */
    [self obtainConfig];
    dm_PrintLn(@"Running verb %@ for arguments %@", NSStringFromClass([self class]), _arguments);
}

- (void)obtainConfig
{
    NSString* configFile = nil;
    // scan args for -c or --server-config
    NSUInteger config_arg = [_arguments indexOfObject:kFlagServerConfig];
    if (config_arg == NSNotFound)
        config_arg = [_arguments indexOfObject:kFlagServerConfigLong];
    if (config_arg == NSNotFound)
        configFile = kConfigDefault;
    else {
        if ([_arguments count] < config_arg +1) {
            dm_PrintLn(@"No argument given to switch for custom configuration file!");
            exit(-1);
        } else {
            configFile = [_arguments objectAtIndex:config_arg+1];
        }
    }
    
    dm_PrintLn(@"Using configuration file %@", configFile);
    
}

@end
