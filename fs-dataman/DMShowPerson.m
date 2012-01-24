//
//  DMShowPerson.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/24/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMShowPerson.h"

@implementation DMShowPerson

+ (void)load
{
// UNCOMMENT WHEN THE COMMAND IS COMPLETE
//    @autoreleasepool {
//        [[DMVerb registeredCommands] addObject:[self class]];
//    }
}

+ (NSString*)verbCommand
{
    return @"show-person";
}

@end
