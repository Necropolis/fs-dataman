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
    NSString* configFileURI = nil;
    // scan args for -c or --server-config
    NSUInteger config_arg = [_arguments indexOfObject:kFlagServerConfig];
    if (config_arg == NSNotFound)
        config_arg = [_arguments indexOfObject:kFlagServerConfigLong];
    if (config_arg == NSNotFound)
        configFileURI = kConfigDefault;
    else {
        if ([_arguments count] < config_arg +1) {
            dm_PrintLn(@"No argument given to switch for custom configuration file!");
            exit(-1);
        } else {
            configFileURI = [_arguments objectAtIndex:config_arg+1];
        }
    }
    
    NSFileHandle* configFile = [NSFileHandle fileHandleForReadingAtPath:[configFileURI stringByExpandingTildeInPath]];
    
    if (configFile == nil) {
        dm_PrintLn(@"Configuration file at %@ doesn't seem to exist.", configFileURI);
        exit(-1);
    }
    
    NSError* parse = nil;
    self.configuration =
    [NSPropertyListSerialization propertyListWithData:[configFile readDataToEndOfFile]
                                              options:NSPropertyListImmutable
                                               format:NULL
                                                error:&parse];
    
    if (parse) {
        dm_PrintLn(@"Failed to parse the configuration at %@ with the error %@", configFileURI, [parse description]);
        exit(-1);
    }
    
    // the configuration was obtained properly
    
}

@end
