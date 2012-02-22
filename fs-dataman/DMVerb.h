//
//  DMVerb.h
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NDService;

extern NSString* kConfigServerURL;
extern NSString* kConfigAPIKey;
extern NSString* kConfigUsername;
extern NSString* kConfigPassword;

extern NSString* kConfigSoftShort;
extern NSString* kConfigSoftLong;
extern NSString* kConfigForceShort;
extern NSString* kConfigForceLong;
extern NSString* kConfigLinkShort;
extern NSString* kConfigLinkLong;

enum flag_t {
    NONE=0,
    SOFT=1,
    FORCE=1<<1,
    LINK=1<<2
};

#define MODE_NONE(f)           (0==( f & NONE          ))
#define MODE_SOFT(f)           (0==( f & SOFT          ))
#define MODE_FORCE(f)          (0==( f & FORCE         ))
#define MODE_LINK(f)           (0==( f & LINK          ))
#define MODE_SOFT_AND_FORCE(f) (0==( f & ( SOFT|FORCE )))

@interface DMVerb : NSObject

@property (readwrite, strong) NSArray* __arguments_raw;
@property (readwrite, strong) NSArray * flags;
@property (readwrite, strong) NSDictionary * arguments;
@property (readwrite, strong) NSArray * unnamedArguments;
@property (readwrite, strong) NDService* service;
@property (readwrite, strong) NSDictionary* configuration;
@property (readwrite, strong) NSDictionary* me;

+ (NSMutableArray*)registeredCommands;
+ (NSString*)verbCommand;
+ (NSString*)manpage;

- (NSArray *)argumentSignatures;
- (BOOL)shouldLogin;

- (NSString*)verbHeader;
- (NSString*)verbFooter;
- (void)setUp;
- (void)processArgs;
- (void)run;
- (void)tearDown;

- (BOOL)hasFlagAndRemove:(id)flagNames;
- (NSString *)getSingleArgument:(id)argName;

- (void)getMe;

@end
