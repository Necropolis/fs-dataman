//
//  DMVerb.h
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 FSDEV. All rights reserved.
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

enum flag_t {
    NONE=0,
    SOFT=1,
    FORCE=1<<1
};

#define MODE_NONE(f) (( f & NONE) == 0)
#define MODE_SOFT(f) (( f & SOFT) == 0)
#define MODE_FORCE(f) (( f & FORCE) == 0)
#define MODE_SOFT_AND_FORCE(f) (( f & ( SOFT|FORCE ))==0)

@interface DMVerb : NSObject

@property (readwrite, strong) NSArray* arguments;
@property (readwrite, strong) NDService* service;
@property (readwrite, strong) NSDictionary* configuration;

- (NSString*)verbHeader;
- (void)setUp;
- (void)processArgs;
- (void)run;
- (void)tearDown;

@end
