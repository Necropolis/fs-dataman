//
//  DMDeploy.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMNFSDeploy.h"

#import "Console.h"

#import "FSArgumentSignature.h"

#import "FSGEDCOM.h"

@implementation DMNFSDeploy {
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
    return @"nfs-deploy";
}

+ (NSString*)manpage
{
    return @"fs-dataman-nfs-deploy";
}

- (NSArray *)argumentSignatures
{
    return [NSArray arrayWithObjects:
            [FSArgumentSignature argumentSignatureWithNames:[NSArray arrayWithObjects:@"-s", @"--soft", nil] flag:YES required:NO multipleAllowed:NO],
            [FSArgumentSignature argumentSignatureWithNames:[NSArray arrayWithObjects:@"-f", @"--force", nil] flag:YES required:NO multipleAllowed:NO],
            nil];
}

- (void)processArgs
{
    _flag = NONE;
    // grab soft flag
    if ([self.flags containsObject:kConfigSoftShort])
        _flag = SOFT;
    if ([self.unnamedArguments count] != 2)
        dm_PrintLnThenDie(@"Incorrect number of file arguments. I'm going to stop now before I hurt myself.");
    __ifilelocation = [[self.unnamedArguments objectAtIndex:0] stringByExpandingTildeInPath];
    __ofilelocation = [[self.unnamedArguments lastObject] stringByExpandingTildeInPath];
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
    [parsed_gedcom parse:[self.gedcom readDataToEndOfFile]];

    dm_PrintLn(@"results of parsing gedcom: %@", parsed_gedcom);
}

@end
