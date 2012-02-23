//
//  DMGEDListIndividuals.m
//  fs-dataman
//
//  Created by Christopher Miller on 2/22/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMGED55ListIndividuals.h"

#import "Console.h"

#import "FSGEDCOM.h"

@implementation DMGED55ListIndividuals {
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
    return @"ged55-list-individuals";
}

+ (NSString*)manpage
{
    return @"fs-dataman-ged55-list-individuals";
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"GED55-LIST-INDIVIDUALS on %@", _gedcomFilename];
}

- (BOOL)shouldLogin { return NO; }

- (void)processArgs
{
    if ([self.arguments.unnamedArguments count]!=1) dm_PrintLnThenDie(@"Improper number of freakin files specified man!");
    _gedcomFilename = [[self.arguments.unnamedArguments lastObject] stringByExpandingTildeInPath];
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
    
    __block NSUInteger maxIdLength = 0;
    
    NSArray * sortedKeys = [[parsed_gedcom.individuals allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2 options:NSCaseInsensitiveSearch|NSNumericSearch];
    }];
    [sortedKeys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSUInteger l = [obj length];
        if (l>maxIdLength) maxIdLength=l;
    }];
    dm_PrintLn(@"Records:");
    [sortedKeys enumerateObjectsUsingBlock:^(NSString * obj, NSUInteger idx, BOOL *stop) {
        id name = [[parsed_gedcom.individuals objectForKey:obj] valueForKeyPath:@"NAME.value"];
        if ([name isKindOfClass:[NSArray class]]) name = [name lastObject];
        if (name==nil) name = @"<<UNNAMED>>";
        dm_PrintLn(@"  %@: %@", [obj stringByPaddingToLength:maxIdLength withString:@" " startingAtIndex:0], name);
    }];
}

@end
