//
//  DMInspect.m
//  dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 FSDEV. All rights reserved.
//

#import "DMInspect.h"

#import "Console.h"

@implementation DMInspect

@synthesize objectIds=_objectIds;
@synthesize gedcom=_gedcom;

- (void)processArgs
{
    if ([self.arguments count] < 1) {
        dm_PrintLn(@"No output file or GEDCOM exemplar specified. I'm going to stop now before I hurt myself.");
        exit(-1);
    } else if ([self.arguments count] > 2) {
        dm_PrintLn(@"More arguments than necessary. I'm confused, so I'm going to stop now before I hurt myself.");
        exit(-1);
    }
    
    NSString* objectIdFileLocation = [self.arguments objectAtIndex:0];
    if ([self.arguments count] == 2) { dm_PrintLn(@"Unimplemented feature."); exit(-1); }
    
    [[NSFileManager defaultManager] createFileAtPath:[objectIdFileLocation stringByExpandingTildeInPath]
                                            contents:[NSData data]
                                          attributes:nil];
    
    self.objectIds = [NSFileHandle fileHandleForWritingAtPath:[objectIdFileLocation stringByExpandingTildeInPath]];
    [self.objectIds truncateFileAtOffset:0]; // ensure that the darn thing is empty!
}

- (void)run
{
    // traverse the effing tree
}

@end
