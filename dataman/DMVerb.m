//
//  Verb.m
//  dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 FSDEV. All rights reserved.
//

#import "DMVerb.h"

#import "Console.h"

@implementation DMVerb

@synthesize arguments = _arguments;

- (void)run
{
    /*
     global:
        optional args:
            -c --server-config FILE session config file (use default location if an explicit location is not set)
     */
    
    dm_PrintLn(@"Running verb %@ for arguments %@", NSStringFromClass([self class]), _arguments);
}

@end
