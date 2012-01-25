//
//  Console.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "Console.h"

#include <stdio.h>

#import "NSData+StringValue.h"

NSString* dm_stringIndentingWithString(NSString* string, NSString* indent);

void dm_Print  (NSString* format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString* s0 = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    printf("%s", [s0 UTF8String]);
}

void dm_PrintLn(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString* s0 = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    printf("%s\n", [s0 UTF8String]);
}

void dm_PrintLnThenDie(NSString* format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString* s0 = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    printf("%s\n", [s0 UTF8String]);
    exit(-1);
}

void dm_PrintURLOperationResponse(NSHTTPURLResponse* resp, NSData* payload, NSError* error)
{
    NSString* indent = @"   ";
    
    printf("\n");
    dm_PrintLn(@"%@", dm_stringIndentingWithString([NSString stringWithFormat:@"Error: %@", error], indent));
    dm_PrintLn(@"%@", dm_stringIndentingWithString([NSString stringWithFormat:@"URL Response: %@", [NSHTTPURLResponse localizedStringForStatusCode:[resp statusCode]]], indent));
    dm_PrintLn(@"%@", dm_stringIndentingWithString([NSString stringWithFormat:@"Response Headers: %@", [resp allHeaderFields]], indent));
    dm_PrintLn(@"%@", dm_stringIndentingWithString(@"Response Payload", indent));
    dm_PrintLn(@"%@", dm_stringIndentingWithString([payload fs_stringValue], [NSString stringWithFormat:@"%@%@", indent, indent]));
    printf("\n");
}

NSString* dm_stringIndentingWithString(NSString* string, NSString* indent) {
    NSMutableString* o = [[NSMutableString alloc] init];
    [string enumerateLinesUsingBlock:^(NSString* line, BOOL* stop) {
        [o appendFormat:@"%@%@", indent, line];
    }];
    return o;
}
