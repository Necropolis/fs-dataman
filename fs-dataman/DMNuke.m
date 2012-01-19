//
//  DMNuke.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMNuke.h"

#import "Console.h"

@implementation DMNuke {
    NSString* _ifile;
    NSString* _ofile;
}

@synthesize inputFile=_inputFile;
@synthesize outputFile=_outputFile;
@synthesize flag=_flag;

- (void)processArgs
{
    self.flag = NONE;
    if ([self hasFlagAndRemove:[NSArray arrayWithObjects:kConfigForceLong, kConfigForceShort, nil]])
        self.flag = FORCE;
    if ([self hasFlagAndRemove:[NSArray arrayWithObjects:kConfigSoftLong, kConfigSoftShort, nil]])
        self.flag |= SOFT;
    if ([self.arguments count]!=2)
        dm_PrintLn(@"Incorrect number of file arguments for command.");
    // check files
    _ifile=[[self.arguments objectAtIndex:0] stringByExpandingTildeInPath];
    _ofile=[[self.arguments lastObject] stringByExpandingTildeInPath];
    NSFileManager* _mgr=[NSFileManager defaultManager];
    if ([_mgr fileExistsAtPath:_ifile]&&[_mgr isReadableFileAtPath:_ifile]) {
        self.inputFile = [NSFileHandle fileHandleForReadingAtPath:_ifile];
        NSAssert(_inputFile!=nil,@"Seriously, how can this freaking happen?");
    } else {
        dm_PrintLn(@"I cannot open the input file for reading. Dude, this is totally not cool. I'm gunna quit now.");
        exit(-1);
    }
    [_mgr createFileAtPath:_ofile
                  contents:[NSData data]
                attributes:nil];
    self.outputFile = [NSFileHandle fileHandleForWritingAtPath:_ofile];
    if (self.outputFile==nil) {
        dm_PrintLn(@"I cannot open the output file for writing. Dude, this is totally not cool. I'm gunna quit now.");
        exit(-1);
    }
    [self.outputFile truncateFileAtOffset:0];
    // all should be well in Zion, right?
}

- (NSString*)verbHeader
{
    NSMutableString* header = [[NSMutableString alloc] init];
    [header appendString:@"NUKE with modes "];
    if (MODE_NONE(self.flag)) [header appendString:@"NONE"];
    else {
        if (MODE_SOFT(self.flag)) [header appendString:@"SOFT"];
        if (MODE_SOFT_AND_FORCE(self.flag)) [header appendString:@","];
        if (MODE_FORCE(self.flag)) [header appendString:@"FORCE"];
    }
    [header appendFormat:@" with ifile: %@ & ofile: %@", _ifile, _ofile];
    return header;
}

- (void)run
{
    // /run/dos/run https://devnet.familysearch.org/docs/api/familytree-v2/guides/deleting-a-person
}

@end
