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
#import "FSURLOperation.h" // how we count requests

int main (int argc, const char * argv[])
{

    @autoreleasepool {
        
        __block size_t runningOperations = 0;
        __block size_t operationsExecuted = 0;
#ifdef DEBUG
        __block NSError * ___error=nil;
        __block NSRegularExpression * devKeyRegex = [[NSRegularExpression alloc] initWithPattern:@"(\\??&?key\\=)((?:\\w{4}\\-?){8})" options:0 error:&___error];
        __block NSRegularExpression * sessionIdRegex = [[NSRegularExpression alloc] initWithPattern:@"(\\??&?sessionId=[^\\&]+)" options:0 error:&___error];
        __block NSRegularExpression * dataFormatRegex = [[NSRegularExpression alloc] initWithPattern:@"(\\??&?dataFormat=application\\/json)" options:0 error:&___error];
        NSString * (^washURL)(NSURL * url) = ^NSString *(NSURL * url) {
            NSMutableString * requestURL = [[url description] mutableCopy];
            
            [devKeyRegex replaceMatchesInString:requestURL options:0 range:NSMakeRange(0, [requestURL length]) withTemplate:@""];
            [sessionIdRegex replaceMatchesInString:requestURL options:0 range:NSMakeRange(0, [requestURL length]) withTemplate:@""];
            [dataFormatRegex replaceMatchesInString:requestURL options:0 range:NSMakeRange(0, [requestURL length]) withTemplate:@""];
            
            return [requestURL copy];
        };
#endif
        [[FSURLOperation globalBlockCallbacks_requestStarted] addObject:^(NSURLRequest * request, NSThread * t) {
            ++runningOperations;
#ifdef DEBUG
            dm_PrintLn(@">>> Executing Operations: %4lu Finished Operations: %6lu\n"
                       @"    Started %@ %@\n"
                       @"    On thread %@\n", runningOperations, operationsExecuted, request.HTTPMethod, washURL(request.URL), t.name);
#endif
        }];
        [[FSURLOperation globalBlockCallbacks_requestFinished] addObject:^(NSURLRequest * request, NSThread * t, NSHTTPURLResponse * response, NSData * payload, NSError * error) {
            --runningOperations;
            ++operationsExecuted;
#ifdef DEBUG
            dm_PrintLn(@">>> Executing Operations: %4lu Finished Operations: %6lu\n"
                       @"    Finished %@ %@\n"
                       @"    On thread %@\n", runningOperations, operationsExecuted, request.HTTPMethod, washURL(request.URL), t.name);
#endif
        }];
        
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
            
            [verb_impl parseArgs:[args subarrayWithRange:NSMakeRange(2, [args count] -2)]];
            
            [verb_impl setUp];
            [verb_impl run];
            [verb_impl tearDown];
        }
        
        dm_PrintLn(@"  Command executed %lu HTTP requests.", operationsExecuted);
    }
    
    return 0;
}

