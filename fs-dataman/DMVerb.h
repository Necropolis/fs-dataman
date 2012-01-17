//
//  Verb.h
//  dataman
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

@interface DMVerb : NSObject

@property (readwrite, strong) NSArray* arguments;
@property (readwrite, strong) NDService* service;
@property (readwrite, strong) NSDictionary* configuration;

- (void)setUp;
- (void)run;
- (void)tearDown;

@end
