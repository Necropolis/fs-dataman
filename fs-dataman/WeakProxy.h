//
//  WeakProxy.h
//  fs-dataman
//
//  Created by Christopher Miller on 3/9/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import <Foundation/Foundation.h>

// very much pilfered from http://stackoverflow.com/a/3618797/622185
@interface WeakProxy : NSProxy {
@protected
    __weak id _object;
}

@property (readwrite, weak) id object;

+ (id)weakProxyWithObject:(id)object;
- (id)initWithObject:(id)object;

@end
