//
//  DMNFSPersonNode.h
//  fs-dataman
//
//  Created by Christopher Miller on 3/9/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NDService;

#define kDMNFSPERSONNODE_TRAVERSE_LOCK_TIMEOUT 30.0f

enum DMNFSPersonNode_TraversalState {
    kTraverseState_Untraversed,
    kTraverseState_Traversing,
    kTraverseState_Traversed
};

enum DMNFSPersonNode_WriteState {
    kWriteState_Idle,
    kWriteState_Active
};

enum DMNFSPersonNode_TearDownState {
    kTearDownState_None=0,
    kTearDownState_IndividualAssertions=1,
    kTearDownState_ChildAssertions=1<<2,
    kTearDownState_ParentAssertions=1<<3,
    kTearDownState_SpouseAssertions=1<<4
};

/**
 * Maintains an object graph of PIDs and their associated locks.
 */
@interface DMNFSPersonNode : NSObject <NSCopying>

@property (strong) NSString * pid;
@property (assign, getter = isMe) BOOL me;
@property (strong) NSSet * children; // links to other nodes through proxy objects
@property (strong) NSSet * parents; // links to other nodes through proxy objects
@property (strong) NSSet * spouses; // links to other nodes through proxy objects
@property (assign) enum DMNFSPersonNode_TraversalState traversalState;
@property (assign) enum DMNFSPersonNode_WriteState writeState;
@property (assign) enum DMNFSPersonNode_TearDownState tearDownState;

- (id)initWithPID:(NSString *)pid;

#pragma mark Traversal

- (BOOL)isTraversed;
- (void)traverseTreeWithService:(NDService *)service globalNodeSet:(NSMutableSet *)allNodes recursive:(BOOL)recursive queue:(NSOperationQueue *)q;

#pragma mark Tear Down

- (NSArray *)tearDownWithService:(NDService *)service queue:(NSOperationQueue *)q allOperations:(NSArray *)allOperations soft:(BOOL)soft;

@end
