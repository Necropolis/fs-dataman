//
//  DMNFSPersonNode_IndividualAssertionsDeleteWrapperOperation.h
//  fs-dataman
//
//  Created by Christopher Miller on 3/12/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DMNFSPersonNode;
@class NDService;

// I should win some kind of prize for having the longest class name
@interface DMNFSPersonNode_IndividualAssertionsDeleteWrapperOperation : NSOperation

@property (strong) DMNFSPersonNode * personToKill;
@property (strong) NDService * service;
@property (assign) BOOL soft;

+ (id)individualAssertionsDeleteWrapperOperationWithPersonNode:(DMNFSPersonNode *)node service:(NDService *)service soft:(BOOL)soft;
- (id)initWithPersonNode:(DMNFSPersonNode *)node service:(NDService *)service soft:(BOOL)soft;

@end
