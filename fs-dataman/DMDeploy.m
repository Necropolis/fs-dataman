//
//  DMDeploy.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMDeploy.h"

#import "Console.h"

#import "FSGEDCOM.h"

@implementation DMDeploy {
    NSString* __ifilelocation;
    NSString* __ofilelocation;
}

@synthesize gedcom=_gedcom;
@synthesize outputFile=_outputFile;
@synthesize flag=_flag;

+ (void)load
{
// UNCOMMENT WHEN THE COMMAND IS COMPLETE
    @autoreleasepool {
        [[DMVerb registeredCommands] addObject:[self class]];
    }
}

+ (NSString*)verbCommand
{
    return @"deploy";
}

+ (NSString*)manpage
{
    return @"fs-dataman-deploy";
}

- (void)processArgs
{
    _flag = NONE;
    // grab soft flag
    if ([self hasFlagAndRemove:[NSArray arrayWithObjects:kConfigSoftShort, kConfigSoftLong, nil]])
        _flag = SOFT;
    if ([self.arguments count] != 2) {
        dm_PrintLnThenDie(@"Incorrect number of file arguments. I'm going to stop now before I hurt myself.");
    }
    __ifilelocation = [[self.arguments objectAtIndex:0] stringByExpandingTildeInPath];
    __ofilelocation = [[self.arguments lastObject] stringByExpandingTildeInPath];
    NSFileManager* _mgr=[NSFileManager defaultManager];
    if ([_mgr fileExistsAtPath:__ifilelocation]&&[_mgr isReadableFileAtPath:__ifilelocation]) {
        self.gedcom = [NSFileHandle fileHandleForReadingAtPath:__ifilelocation];
        NSAssert(_gedcom!=nil,@"Seriously, how can this freaking happen?");
    } else {
        dm_PrintLnThenDie(@"I cannot open the input file for reading. Dude, this is totally not cool. I'm gunna quit now.");
    }
    [_mgr createFileAtPath:__ofilelocation
                  contents:[NSData data]
                attributes:nil];
    self.outputFile = [NSFileHandle fileHandleForWritingAtPath:__ofilelocation];
    if (self.outputFile==nil) {
        dm_PrintLnThenDie(@"I cannot open the output file for writing. Dude, this is totally not cool. I'm gunna quit now.");
    }
    [self.outputFile truncateFileAtOffset:0];
    // all should be well in Zion, right?
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"DEPLOY gedcom: %@ object id file: %@", __ifilelocation, __ofilelocation];
}

- (void)run
{
    FSGEDCOM* parsed_gedcom = [[FSGEDCOM alloc] init];
    NSDictionary* gedcom_results = [parsed_gedcom parse:[self.gedcom readDataToEndOfFile]];

    dm_PrintLn(@"results of parsing gedcom: %@", gedcom_results);
}

@end
