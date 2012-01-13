//
//  Verb.h
//  dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 FSDEV. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DMVerb : NSObject

@property (readwrite, strong) NSArray* arguments;

- (void)run;

@end
