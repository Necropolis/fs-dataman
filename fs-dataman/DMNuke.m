//
//  FSMNuke.m
//  dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 FSDEV. All rights reserved.
//

#import "DMNuke.h"

@implementation DMNuke

- (void)run
{
    [super run];
    /*
     nuke:
        required args:
            object id input file
            object id output file (for any stragglers that it was unable to delete)
        optional args:
            -s --soft soft (don't nuke from reference, just inspect what would get nuked)
            -f --force force (if you find something preventing a delete, go delete that recursively)
     */
}

@end
