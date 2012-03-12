//
//  DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation.h
//  fs-dataman
//
//  Created by Christopher Miller on 3/12/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DMNFSPersonNode;
@class NDService;

// I should win some kind of prize for having the longest class name
@interface DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation : NSOperation

@property (strong) DMNFSPersonNode * fromPerson;
@property (strong) DMNFSPersonNode * toPerson;
@property (strong) NSString * relationshipType;
@property (strong) NDService * service;
@property (strong) NSOperationQueue * q;
@property (assign) BOOL soft;

+ (id)relationshipAssertionsDeleteWrapperOperationFromPerson:(DMNFSPersonNode *)fromPerson toPerson:(DMNFSPersonNode *)toPerson relationshipType:(NSString *)relationshipType service:(NDService *)service queue:(NSOperationQueue *)q soft:(BOOL)soft;
- (id)initWithFromPerson:(DMNFSPersonNode *)fromPerson toPerson:(DMNFSPersonNode *)toPerson relationshipType:(NSString *)relationshipType service:(NDService *)service queue:(NSOperationQueue *)q soft:(BOOL)soft;

@end
