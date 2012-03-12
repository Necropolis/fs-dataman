//
//  WeakProxy.m
//  fs-dataman
//
//  Created by Christopher Miller on 3/9/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "WeakProxy.h"

@implementation WeakProxy

@synthesize object=_object;

+ (id)weakProxyWithObject:(id)object
{
    return [[[self class] alloc] initWithObject:object];
}

- (id)initWithObject:(id)object
{
    _object = object;
    return self;
}

- (BOOL)isKindOfClass:(Class)aClass {
    return [super isKindOfClass:aClass] || [_object isKindOfClass:aClass];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation setTarget:_object];
    [invocation invoke];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [_object methodSignatureForSelector:sel];
}

@end