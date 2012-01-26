//
//  DMCapture.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/19/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMCapture.h"

#import "Console.h"

@implementation DMCapture {
    NSString* __outputfilelocation;
}

@synthesize ofile=_ofile;

+ (void)load
{
// UNCOMMENT WHEN THE COMMAND IS COMPLETE
//    @autoreleasepool {
//        [[DMVerb registeredCommands] addObject:[self class]];
//    }
}

+ (NSString*)verbCommand
{
    return @"capture";
}

+ (NSString*)manpage
{
    return @"fs-dataman-capture";
}

- (void)processArgs
{
    if ([self.arguments count] != 1) { dm_PrintLnThenDie(@"More than one path given. I'm gunna panic now."); }
    
    __outputfilelocation = [[self.arguments objectAtIndex:0] stringByExpandingTildeInPath];
    
    [[NSFileManager defaultManager] createFileAtPath:__outputfilelocation
                                            contents:[NSData data]
                                          attributes:nil];
    
    self.ofile = [NSFileHandle fileHandleForWritingAtPath:__outputfilelocation];
    [self.ofile truncateFileAtOffset:0]; // ensure that the darn thing is empty!
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"CAPTURE all currently visible data into new GEDCOM at %@", __outputfilelocation];
}

@end
