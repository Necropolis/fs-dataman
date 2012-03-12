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

/**
 * Maintains an object graph of PIDs and their associated locks.
 */
@interface DMNFSPersonNode : NSObject <NSCopying>

@property (strong) NSString * pid;
@property (assign, getter = isMe) BOOL me;
@property (strong) NSLock * lock;
@property (strong) NSSet * children; // links to other nodes through proxy objects
@property (strong) NSSet * parents; // links to other nodes through proxy objects
@property (strong) NSSet * spouses; // links to other nodes through proxy objects
@property (assign) enum DMNFSPersonNode_TraversalState state;

- (id)initWithPID:(NSString *)pid;

- (BOOL)lockBeforeDate:(NSDate *)date byAuthority:(id)auth;
- (void)unlock;

#pragma mark Traversal

- (BOOL)isTraversed;
- (void)traverseTreeWithService:(NDService *)service globalNodeSet:(NSMutableSet *)allNodes recursive:(BOOL)recursive queue:(NSOperationQueue *)q lockOrigin:(id)lockOrigin;

@end
