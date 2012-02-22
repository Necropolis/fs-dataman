//
//  DMCapture.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/19/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMNFSCapture.h"

#import "Console.h"

@implementation DMNFSCapture {
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
    return @"nfs-capture";
}

+ (NSString*)manpage
{
    return @"fs-dataman-nfs-capture";
}

- (void)processArgs
{
    if ([self.__arguments_raw count] != 1) { dm_PrintLnThenDie(@"More than one path given. I'm gunna panic now."); }
    
    __outputfilelocation = [[self.__arguments_raw objectAtIndex:0] stringByExpandingTildeInPath];
    
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
