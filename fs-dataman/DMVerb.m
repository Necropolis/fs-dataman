//
//  DMVerb.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMVerb.h"

#import "Console.h"

#import "NDService.h"
#import "NDService+Identity.h"
#import "NDService+FamilyTree.h"
#import "NSData+StringValue.h"

#import "FSURLOperation.h"

// remember to update the manpage if these change
NSString* kConfigDefault   = @"~/.fs-dataman.plist";
NSString* kConfigServerURL = @"server"          ;
NSString* kConfigAPIKey    = @"apikey"          ;
NSString* kConfigUsername  = @"username"        ;
NSString* kConfigPassword  = @"password"        ;

NSString* kUserAgent       = @"fs-dataman 0.1"  ;

NSString* kFlagServerConfig = @"-c";
NSString* kFlagServerConfigLong = @"--server-config";

NSString* kConfigSoftShort  = @"-s"      ;
NSString* kConfigSoftLong   = @"--soft"  ;
NSString* kConfigForceShort = @"-f"      ;
NSString* kConfigForceLong  = @"--force" ;
NSString* kConfigLinkShort  = @"-l"      ;
NSString* kConfigLinkLong   = @"--link"  ;

@interface DMVerb (__private__)

- (void)obtainConfig;
- (void)setUpService;

@end

@implementation DMVerb

@synthesize arguments = _arguments;
@synthesize service = _service;
@synthesize configuration = _configuration;
@synthesize me = _me;

+ (NSMutableArray*)registeredCommands
{
    static NSMutableArray* a;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        a = [[NSMutableArray alloc] init];
    });
    return a;
}

+ (NSString*)verbCommand
{
    return @"";
}

- (void)setUp
{
    [self processArgs];
    dm_PrintLn(@"%@\n", [self verbHeader]);
    [self obtainConfig];
    [self setUpService];
}

- (NSString*)verbHeader
{
    return [NSString stringWithFormat:@">>> BEGIN  %@", self];
}

- (NSString*)verbFooter
{
    return [NSString stringWithFormat:@">>> FINISH %@", self];
}

- (void)processArgs
{
    // stop complaining, silly compiler!
}

- (void)run
{
    // stub?
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
            dm_PrintLnThenDie(@"No argument given to switch for custom configuration file!");
        } else {
            configFileURI = [_arguments objectAtIndex:config_arg+1];
            // remove the two flags so it's not a problem for other verbs
            
            NSMutableArray* arr = [[NSMutableArray alloc] init];
            
            if (config_arg>0) [arr addObjectsFromArray:[_arguments subarrayWithRange:NSMakeRange(0, config_arg)]];
            [arr addObjectsFromArray:[_arguments subarrayWithRange:NSMakeRange(config_arg+2, [_arguments count]-(config_arg+2))]];
            
            self.configuration = [arr copy]; // preseve immutability
        }
    }
    
    NSFileHandle* configFile = [NSFileHandle fileHandleForReadingAtPath:[configFileURI stringByExpandingTildeInPath]];
    
    if (configFile == nil) {
        dm_PrintLnThenDie(@"Configuration file at %@ doesn't seem to exist.", configFileURI);
    }
    
    NSError* parse = nil;
    self.configuration =
    [NSPropertyListSerialization propertyListWithData:[configFile readDataToEndOfFile]
                                              options:NSPropertyListImmutable
                                               format:NULL
                                                error:&parse];
    
    if (parse) {
        dm_PrintLnThenDie(@"Failed to parse the configuration at %@ with the error %@", configFileURI, [parse description]);
    }
    
    // the configuration was obtained properly
    
    
    if ([[self.configuration valueForKey:kConfigServerURL] rangeOfString:@"api.familysearch.org" options:NSCaseInsensitiveSearch].location!=NSNotFound) {
        dm_PrintLn(@"BIG FREAKING PROBLEM! YOU'RE TRYING TO RUN THIS ON THE PRODUCTION CLUSTER! I WILL NOT ALLOW THIS!");
        dm_PrintLnThenDie(@"Ensure that your server configuration is NOT api.familysearch.org!");
    }
}

- (void)setUpService
{
    self.service = [[NDService alloc] initWithBaseURL:[NSURL URLWithString:[self.configuration valueForKey:kConfigServerURL]]
                                            userAgent:kUserAgent];
    [self.service.operationQueue setMaxConcurrentOperationCount:NSIntegerMax]; // dude, this is running on a developer machine. pound those API calls!
    
    FSURLOperation* login =
    [self.service identityOperationCreateSessionForUser:[self.configuration valueForKey:kConfigUsername]
                                           withPassword:[self.configuration valueForKey:kConfigPassword]
                                                 apiKey:[self.configuration valueForKey:kConfigAPIKey]
                                              onSuccess:^(NSHTTPURLResponse* resp, id response, NSData* payload) {
                                                  dm_PrintLn(@"Created session %@", self.service.sessionId);
                                              }
                                              onFailure:^(NSHTTPURLResponse* resp, NSData* payload, NSError* error) {
                                                  dm_PrintLn(@"Login failure!");
                                                  
                                                  dm_PrintURLOperationResponse(resp, payload, error);
                                                  
                                                  exit(-1);
                                              }];
    [self.service.operationQueue addOperation:login];
    [login waitUntilFinished];
}

- (void)tearDown
{
    FSURLOperation* logout =
    [self.service identityOperationDestroySessionOnSuccess:^(NSHTTPURLResponse* resp, id response, NSData* payload) {
        dm_PrintLn(@"Destroyed session");
    } onFailure:^(NSHTTPURLResponse* resp, NSData* payload, NSError* error) {
        dm_PrintLn(@"Failed to logout!");
        
        dm_PrintURLOperationResponse(resp, payload, error);
        
        exit(-1);
    }];
    [self.service.operationQueue addOperation:logout];
    [logout waitUntilFinished];
    dm_PrintLn(@"\n%@", [self verbFooter]);
}

- (BOOL)hasFlagAndRemove:(NSArray*)flag
{
    BOOL has=NO;
    for (NSString* f in flag) {
        if ([self.arguments containsObject:f]) {
            has=YES;
            NSMutableArray* arr=[self.arguments mutableCopy];
            [arr removeObjectsInArray:flag];
            self.arguments = [arr copy];
            break;
        }
    }
    return has;
}

- (void)getMe
{
    FSURLOperation* getMe =
    [self.service familyTreeOperationReadPersons:[NSArray array] withParameters:nil onSuccess:^(NSHTTPURLResponse* resp, id response, NSData* payload) {
        self.me = response;
    } onFailure:^(NSHTTPURLResponse* resp, NSData* payload, NSError* error) {
        dm_PrintLn(@"Failed to get current user in the tree!");
        dm_PrintURLOperationResponse(resp, payload, error);
        exit(-1);
    }];
    [self.service.operationQueue addOperation:getMe];
    [getMe waitUntilFinished];
}

@end
