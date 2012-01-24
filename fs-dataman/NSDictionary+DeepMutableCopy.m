//
//  NSDictionary+DeepMutableCopy.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/24/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "NSDictionary+DeepMutableCopy.h"

#import "NSArray+DeepMutableCopy.h"

@implementation NSDictionary (DeepMutableCopy)

- (id)fs_deepMutableCopy
{
    NSMutableDictionary* mutableSelf = [self mutableCopy];
    for (id key in [mutableSelf allKeys]) {
        if ([[mutableSelf objectForKey:key] isKindOfClass:[NSDictionary class]] && ![[mutableSelf objectForKey:key] isKindOfClass:[NSMutableDictionary class]]) {
            [mutableSelf setObject:[[mutableSelf objectForKey:key] fs_deepMutableCopy] forKey:key];
        } else if ([[mutableSelf objectForKey:key] isKindOfClass:[NSArray class]] && ![[mutableSelf objectForKey:key] isKindOfClass:[NSMutableArray class]]) {
            [mutableSelf setObject:[[mutableSelf objectForKey:key] fs_deepMutableCopy] forKey:key];
        }
    }
    return mutableSelf;
}

@end
