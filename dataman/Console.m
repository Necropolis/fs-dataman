//
//  Console.m
//  dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 FSDEV. All rights reserved.
//

#import "Console.h"

#import <stdio.h>

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
