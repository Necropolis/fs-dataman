//
//  main.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Console.h"

#import "DMVerb.h"

int main (int argc, const char * argv[])
{

    @autoreleasepool {
        
        NSArray* args = [[NSProcessInfo processInfo] arguments];
        
        if ([args count] < 2) {
            // fire off man
            execlp("man", "man", "fs-dataman", NULL);
        } else {
            NSString* verb = [args objectAtIndex:1];
            
            NSArray* sz_verbs   = [[DMVerb registeredCommands] valueForKey:@"verbCommand"];
            NSArray* objc_verbs = [DMVerb registeredCommands];
            
            NSUInteger i_verb = [objc_verbs indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
                if (NSOrderedSame==[[obj valueForKey:@"verbCommand"] caseInsensitiveCompare:verb]) return YES;
                else return NO;
            }];
            
            if (NSNotFound==i_verb) {
                dm_PrintLnThenDie(@"unknown command %@; I only know about %@", verb, [sz_verbs componentsJoinedByString:@", "]);
            }
            
            DMVerb* verb_impl = [[[objc_verbs objectAtIndex:i_verb] alloc] init];
            
            verb_impl.arguments = [args subarrayWithRange:NSMakeRange(2, [args count] -2)];
            
            [verb_impl setUp];
            [verb_impl run];
            [verb_impl tearDown];
        }        
    }
    
    return 0;
}

