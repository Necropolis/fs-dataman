//
//  DMGEDListIndividuals.m
//  fs-dataman
//
//  Created by Christopher Miller on 2/22/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMGEDListIndividuals.h"

@implementation DMGEDListIndividuals {
    NSString * _gedcomFilename;
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
    return [NSString stringWithFormat:@"GED-LIST-INDIVIDUALS on %%@"];
}

- (void)processArgs
{
    
}

- (void)run
{
    
}

@end
