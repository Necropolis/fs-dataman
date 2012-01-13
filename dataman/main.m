//
//  main.m
//  dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 FSDEV. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Console.h"

#import "DMVerb.h"

// these might be extraneous
#import "DMDeploy.h"
#import "DMNuke.h"
#import "DMInspect.h"

int main (int argc, const char * argv[])
{

    @autoreleasepool {
        
        NSArray* args = [[NSProcessInfo processInfo] arguments];
        
        if ([args count] < 2) {
            dm_PrintLn(@"missing verb!");
            exit(-1);
        }
        
        NSString* verb = [args objectAtIndex:1];
        
        NSArray* sz_verbs = [NSArray arrayWithObjects:@"deploy", @"nuke", @"inspect", nil];
        NSArray* objc_verbs = [NSArray arrayWithObjects:[DMDeploy class], [DMNuke class], [DMInspect class], nil];
        
        if (![sz_verbs containsObject:verb]) {
            dm_PrintLn(@"unknown command %@; I only know about %@", verb, [sz_verbs componentsJoinedByString:@", "]);
            exit(-1);
        }
        
        NSUInteger i_verb = [sz_verbs indexOfObject:verb];
        DMVerb* verb_impl = [[[objc_verbs objectAtIndex:i_verb] alloc] init];
        
        verb_impl.arguments = [args subarrayWithRange:NSMakeRange(2, [args count] -2)];
        
        [verb_impl run];
    }
    
    return 0;
}

