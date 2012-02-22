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

+ (NSString*)manpage
{
    return @"";
}

- (BOOL)shouldLogin { return YES; }

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
    NSString* configFileURI = [self getSingleArgument:[NSArray arrayWithObjects:kFlagServerConfig, kFlagServerConfigLong, nil]];
    if (configFileURI==nil) configFileURI = kConfigDefault;
    
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

- (BOOL)hasFlagAndRemove:(id)flagNames
{
    NSArray * _flag;
    if ([flagNames isKindOfClass:[NSString class]]) _flag = [NSArray arrayWithObject:flagNames];
    else _flag = flagNames;
    BOOL has=NO;
    for (NSString* f in _flag) {
        if ([self.arguments containsObject:f]) {
            has=YES;
            NSMutableArray* arr=[self.arguments mutableCopy];
            [arr removeObjectsInArray:flagNames];
            self.arguments = [arr copy];
            break;
        }
    }
    return has;
}

- (NSString *)getSingleArgument:(id)argNames
{
    NSArray * _argNames;
    if ([argNames isKindOfClass:[NSString class]]) _argNames = [NSArray arrayWithObject:argNames];
    else _argNames = argNames;
    for (NSString * n in _argNames) {
        NSUInteger i = [self.arguments indexOfObject:n];
        if (i == NSNotFound) continue;
        if (i == [self.arguments count]-1) return nil;
        NSString * t = [self.arguments objectAtIndex:i+1];
        NSMutableArray * arr = [self.arguments mutableCopy];
        [arr removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(i, 2)]];
        self.arguments = [arr copy];
        return t;
    }
    return nil;
}

- (NSArray *)getArgumentList:(id)argNames withEndingSentinel:(id)sentinel
{
    NSArray * _argNames;
    if ([argNames isKindOfClass:[NSString class]]) _argNames = [NSArray arrayWithObject:argNames];
    else _argNames = argNames;
    
    NSRegularExpression * _sentinelRegex;
    NSString * _sentinelString;
    BOOL isRegex = [sentinel isKindOfClass:[NSRegularExpression class]];
    if (isRegex) _sentinelRegex = sentinel;
    else _sentinelString = sentinel;
    
    NSMutableArray * returnVal = [NSMutableArray array];
    
    for (NSString * n in _argNames) {
        NSUInteger i = [self.arguments indexOfObject:n];
        if (i == NSNotFound) continue;
        if (i == [self.arguments count]-1) return nil;
        for (NSUInteger _i = i+1;
             _i < [self.arguments count];
             ++_i) {
            NSString * _s = [self.arguments objectAtIndex:_i];
            if (isRegex) {
                if (0<[_sentinelRegex numberOfMatchesInString:_s options:0 range:NSMakeRange(0, [_s length])]) break;
            } else {
                if ([_s isEqualToString:_sentinelString]) break;
            }
            [returnVal addObject:_s];
        }
        NSMutableArray * arr = [self.arguments mutableCopy];
        [arr removeObjectsInRange:NSMakeRange(i, [returnVal count]+1)];
        self.arguments = [arr copy];
        return returnVal;
    }
    return nil;
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
