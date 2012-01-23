//
//  DMLink.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/19/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMLink.h"

#import "Console.h"

@implementation DMLink {
    NSString* __ifilelocation;
}

@synthesize objectIdsFile=_objectIdsFile;

- (void)processArgs
{
    if ([self.arguments count]!=1) {
        dm_PrintLn(@"Incorrect number of arguments.");
        exit(-1);
    }
    
    __ifilelocation = [[self.arguments objectAtIndex:0] stringByExpandingTildeInPath];
    NSFileManager* _mgr=[NSFileManager defaultManager];
    if ([_mgr fileExistsAtPath:__ifilelocation]&&[_mgr isReadableFileAtPath:__ifilelocation]) {
        self.objectIdsFile = [NSFileHandle fileHandleForReadingAtPath:__ifilelocation];
        NSAssert(_objectIdsFile!=nil,@"Seriously, how can this freaking happen?");
    } else {
        dm_PrintLn(@"I cannot open the input file for reading. Dude, this is totally not cool. I'm gunna quit now.");
        exit(-1);
    }
    // all should be well in Zion, right?
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"LINK as parents the ids from file %@ to current the user", __ifilelocation];
}

@end
