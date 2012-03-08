//
//  DMVerb.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMVerb.h"

#import "Console.h"

#import "FSArgumentParser.h"
#import "FSArgumentSignature.h"

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
@synthesize startTime=_startTime;
@synthesize endTime=_endTime;

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

- (NSArray *)argumentSignatures { return [NSArray array]; }

- (FSArgumentSignature *)configFlag
{
    static FSArgumentSignature * configFlag;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        configFlag = [FSArgumentSignature argumentSignatureAsNamedArgument:@"c" longNames:@"server-config" required:NO multipleAllowed:NO];
    });
    return configFlag;
}

- (void)parseArgs:(NSArray *)args
{
    NSError * error;
    self.arguments = [FSArgumentParser parseArguments:args withSignatures:[[self argumentSignatures] arrayByAddingObject:[self configFlag]] error:&error];
    if (error) {
        switch ([error code]) {
            case ImpureSignatureArray:
                dm_PrintLnThenDie(@"Impure signature array! %@", [error userInfo]);
                break;
                
            case OverlappingArgument:
                dm_PrintLnThenDie(@"Overlapping argument signatures! %!", [error userInfo]);
                break;
                
            case TooManySignatures:
                dm_PrintLnThenDie(@"Too many signatures for flag! %@", [error userInfo]);
                break;
                
            default:
                // do nothing; chain the error the the subclass
                [self processArgError:error];
                break;
        }
    }
}

- (void)processArgError:(NSError *)error
{
    switch ([error code]) {
        case MissingSignatures:
            dm_PrintLnThenDie(@"Missing arguments! %@", [error userInfo]);
            break;
            
        case ArgumentMissingValue:
            dm_PrintLnThenDie(@"Missing value for argument! %@", [error userInfo]);
            break;
            
        default:
            dm_PrintLnThenDie(@"Unknown parse error! %@", error);
            break;
    }
}

- (void)setUp
{
    self.startTime = [NSDate date];
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
    NSString* configFileURI = [self.arguments.namedArguments objectForKey:kFlagServerConfig];
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
    if ([self shouldLogin]) {
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
}

- (void)tearDown
{
    if ([self shouldLogin]) {
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
    }
    dm_PrintLn(@"\n%@", [self verbFooter]);
    self.endTime = [NSDate date];
    NSTimeInterval runningTime = [self.endTime timeIntervalSinceDate:self.startTime];
    double minutes = floor(runningTime/60.);
    double seconds = floor(runningTime-(minutes*60.));
    dm_PrintLn(@"\n  Command took %d:%d", (long)minutes, (long)seconds);
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
