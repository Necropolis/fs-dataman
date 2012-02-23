//
//  DMVerb.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMVerb.h"

#import "Console.h"

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

//@synthesize __arguments_raw = ___arguments_raw;
@synthesize arguments = _arguments;
@synthesize flags = _flags;
@synthesize unnamedArguments = _unnamedArguments;
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

- (NSArray *)argumentSignatures { return [NSArray array]; }

- (void)parseArgs:(NSArray *)immutableArgs
{
    NSMutableArray * args = [immutableArgs mutableCopy];
    NSArray * argumentSignatures = [[self argumentSignatures] arrayByAddingObject:[FSArgumentSignature argumentSignatureWithNames:[NSArray arrayWithObjects:@"-c", @"--server-config", nil] flag:NO required:NO multipleAllowed:NO]];
    
    // check for conflicting flags
    [argumentSignatures enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        FSArgumentSignature * signature = obj;
        [signature.names enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString * name = obj;
            [argumentSignatures enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if (obj == signature) return;
                FSArgumentSignature * _signature = obj;
                if ([_signature.names containsObject:name]) {
                    dm_PrintLnThenDie(@"Conflicting argument names");
                }
            }];
        }];
    }];
    
    NSMutableDictionary * working_arguments = [[NSMutableDictionary alloc] init];
    NSMutableArray * working_unnamed_arguments = [[NSMutableArray alloc] init];
    NSMutableArray * working_flags = [[NSMutableArray alloc] init];
    
    // arguments first
    [[argumentSignatures filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        if (![evaluatedObject isKindOfClass:[FSArgumentSignature class]]) dm_PrintLnThenDie(@"Somehow something that isn't an argument signature got in a list of argument signatures.");
        if ([((FSArgumentSignature *)evaluatedObject) isFlag]) return NO;
        return YES;
    }]] enumerateObjectsUsingBlock:^(FSArgumentSignature * signature, NSUInteger idx, BOOL *stop) {
        NSIndexSet * matching_flags =
        [args indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [signature.names containsObject:obj];
        }];
        if ([matching_flags count]>1&&![signature isMultipleAllowed]) dm_PrintLnThenDie(@"Found more than one argument of type %@ when that isn't allowed!", signature.names);
        if ([matching_flags count]==0&&[signature isRequired]) dm_PrintLnThenDie(@"Missing required argument of type %@", signature.names);
        NSMutableIndexSet * toKill = [[NSMutableIndexSet alloc] init];
        [matching_flags enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            if (idx+1 == [args count]) { // array index out of bounds
                dm_PrintLnThenDie(@"No argument given for %@", signature.names);
            }
            NSString * arg = [args objectAtIndex:idx+1];
            if ([working_arguments objectForKey:signature]==nil)
                [working_arguments setObject:arg forKey:signature];
            else if ([[working_arguments objectForKey:signature] isKindOfClass:[NSArray class]])
                [[working_arguments objectForKey:signature] addObject:arg];
            else
                [working_arguments setObject:[NSMutableArray arrayWithObjects:[working_arguments objectForKey:signature], arg, nil] forKey:signature];
            [toKill addIndex:idx];
            [toKill addIndex:idx+1];
        }];
        [args removeObjectsAtIndexes:toKill];
    }];
    [[working_arguments allKeys] enumerateObjectsUsingBlock:^(FSArgumentSignature * signature, NSUInteger idx, BOOL *stop) {
        [signature.names enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [working_arguments setObject:[working_arguments objectForKey:signature] forKey:signature];
        }];
        [working_arguments removeObjectForKey:signature];
    }];
    
    // flags next
    [[argumentSignatures filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(FSArgumentSignature * signature, NSDictionary *bindings) {
        if (signature.isFlag) return YES;
        return NO;
    }]] enumerateObjectsUsingBlock:^(FSArgumentSignature * signature, NSUInteger idx, BOOL *stop) {
        NSIndexSet * matching_flags =
        [args indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [signature.names containsObject:obj];
        }];
        if ([matching_flags count]>1&&![signature isMultipleAllowed]) dm_PrintLnThenDie(@"Found more than one flag of type %@ when that isn't allowed", signature.names);
        if ([matching_flags count]==0&&[signature isRequired]) dm_PrintLnThenDie(@"Missing required flag of type %@", signature.names);
        if ([matching_flags count]>0) [working_flags addObjectsFromArray:signature.names]; // perhaps the number of flags is important?
        [args removeObjectsAtIndexes:matching_flags];
    }];
    
    // what's left are the unnamed args
    [working_unnamed_arguments addObjectsFromArray:args];
    
    self.arguments = [working_arguments copy];
    self.flags = [working_flags copy];
    self.unnamedArguments = [working_unnamed_arguments copy];
    
    dm_PrintLn(@"arguments: %@", _arguments);
    dm_PrintLn(@"flags: %@", _flags);
    dm_PrintLn(@"unnamedArguments: %@", _unnamedArguments);
}

- (void)setUp
{
//    [self parseArgs];
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
    NSString* configFileURI = [self.arguments objectForKey:kFlagServerConfig];
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
