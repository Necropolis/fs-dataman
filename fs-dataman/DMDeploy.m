//
//  DMDeploy.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMDeploy.h"

#import "Console.h"

@implementation DMDeploy {
    NSString* __ifilelocation;
    NSString* __ofilelocation;
}

@synthesize gedcom=_gedcom;
@synthesize outputFile=_outputFile;
@synthesize flag=_flag;

- (void)processArgs
{
    _flag = NONE;
    // grab soft flag
    if ([self hasFlagAndRemove:[NSArray arrayWithObjects:kConfigSoftShort, kConfigSoftLong, nil]])
        _flag = SOFT;
    if ([self.arguments count] != 2) {
        dm_PrintLn(@"Incorrect number of file arguments. I'm going to stop now before I hurt myself.");
        exit(-1);
    }
    __ifilelocation = [[self.arguments objectAtIndex:0] stringByExpandingTildeInPath];
    __ofilelocation = [[self.arguments lastObject] stringByExpandingTildeInPath];
    NSFileManager* _mgr=[NSFileManager defaultManager];
    if ([_mgr fileExistsAtPath:__ifilelocation]&&[_mgr isReadableFileAtPath:__ifilelocation]) {
        self.gedcom = [NSFileHandle fileHandleForReadingAtPath:__ifilelocation];
        NSAssert(_gedcom!=nil,@"Seriously, how can this freaking happen?");
    } else {
        dm_PrintLn(@"I cannot open the input file for reading. Dude, this is totally not cool. I'm gunna quit now.");
        exit(-1);
    }
    [_mgr createFileAtPath:__ofilelocation
                  contents:[NSData data]
                attributes:nil];
    self.outputFile = [NSFileHandle fileHandleForWritingAtPath:__ofilelocation];
    if (self.outputFile==nil) {
        dm_PrintLn(@"I cannot open the output file for writing. Dude, this is totally not cool. I'm gunna quit now.");
        exit(-1);
    }
    [self.outputFile truncateFileAtOffset:0];
    // all should be well in Zion, right?
}

- (void)run
{
    [super run];
    /*
     deploy:
        required args:
            gedcom file
            object id output file (sqlite)
        optional args:
            -s --soft soft (don't deploy to reference)
     */
}

@end
