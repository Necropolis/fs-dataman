//
//  DMHelp.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/26/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMHelp.h"

#import "Console.h"

@implementation DMHelp {
    NSString* _manpage;
}

+ (void)load
{
    @autoreleasepool {
        [[DMVerb registeredCommands] addObject:[self class]];
    }
}

+ (NSString*)verbCommand
{
    return @"help";
}

+ (NSString*)manpage
{
    return @"fs-dataman";
}

- (void)setUp
{
    [self processArgs];
}

- (void)processArgs
{
    if ([self.__arguments_raw count]==0) {
        _manpage = [[self class] manpage];
    } else if ([self.__arguments_raw count]==1) {
        NSString* command = [self.__arguments_raw objectAtIndex:0];
        NSUInteger i = [[[self class] registeredCommands] indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            if (NSOrderedSame==[[obj valueForKey:@"verbCommand"] caseInsensitiveCompare:command]) return YES;
            else return NO;
        }];
        if (NSNotFound==i) {
            dm_PrintLnThenDie(@"I do not have any help for the %@ command", command);
        } else {
            _manpage = [[[[self class] registeredCommands] objectAtIndex:i] manpage];
        }
    } else {
        dm_PrintLnThenDie(@"I cannot display multiple help pages.");
    }
}

- (void)run
{
    execlp("man", "man", [_manpage UTF8String], NULL);
}

- (void)tearDown
{
    // do naught
}

@end
