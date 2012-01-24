//
//  NSArray+DeepMutableCopy.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/24/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "NSArray+DeepMutableCopy.h"

#import "NSDictionary+DeepMutableCopy.h"

@implementation NSArray (DeepMutableCopy)

- (id)fs_deepMutableCopy
{
    NSMutableArray* mutableSelf = [self mutableCopy];
    
    for (NSUInteger i = 0;
         i < [mutableSelf count];
         ++i) {
        if ([[mutableSelf objectAtIndex:i] isKindOfClass:[NSDictionary class]] && ![[mutableSelf objectAtIndex:i] isKindOfClass:[NSMutableDictionary class]]) {
            [mutableSelf replaceObjectAtIndex:i withObject:[[mutableSelf objectAtIndex:i] fs_deepMutableCopy]];
        } else if ([[mutableSelf objectAtIndex:i] isKindOfClass:[NSArray class]] && ![[mutableSelf objectAtIndex:i] isKindOfClass:[NSMutableArray class]]) {
            [mutableSelf replaceObjectAtIndex:i withObject:[[mutableSelf objectAtIndex:i] fs_deepMutableCopy]];
        }
    }
    
    return mutableSelf;
}

@end
