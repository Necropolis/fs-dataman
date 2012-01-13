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
    dm_PrintLn(@"Running verb %@ for arguments %@", NSStringFromClass([self class]), _arguments);
}

@end
