//
//  DMGEDListIndividuals.m
//  fs-dataman
//
//  Created by Christopher Miller on 2/22/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMGEDListIndividuals.h"

#import "Console.h"

#import "FSGEDCOM.h"

@implementation DMGEDListIndividuals {
    NSString * _gedcomFilename;
    NSFileHandle * _gedcomFile;
}

+ (void)load
{
    @autoreleasepool {
        [[DMVerb registeredCommands] addObject:[self class]];
    }
}

+ (NSString*)verbCommand
{
    return @"ged-list-individuals";
}

+ (NSString*)manpage
{
    return @"fs-dataman-ged-list-individuals";
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"GED-LIST-INDIVIDUALS on %@", _gedcomFilename];
}

- (BOOL)shouldLogin { return NO; }

- (void)processArgs
{
    if ([self.unnamedArguments count]!=1) dm_PrintLnThenDie(@"Improper number of freakin files specified man!");
    _gedcomFilename = [[self.unnamedArguments lastObject] stringByExpandingTildeInPath];
    NSFileManager * defaultManager = [NSFileManager defaultManager];
    if (![defaultManager fileExistsAtPath:_gedcomFilename])
        dm_PrintLnThenDie(@"File does not exist at path %@", _gedcomFilename);
    if (![defaultManager isReadableFileAtPath:_gedcomFilename])
        dm_PrintLnThenDie(@"File cannot be read at path %@", _gedcomFilename);
    _gedcomFile = [NSFileHandle fileHandleForReadingAtPath:_gedcomFilename];
}

- (void)run
{
    FSGEDCOM* parsed_gedcom = [[FSGEDCOM alloc] init];
    [parsed_gedcom parse:[_gedcomFile readDataToEndOfFile]];
    
    dm_PrintLn(@"results of parsing gedcom: %@", parsed_gedcom);
}

@end
