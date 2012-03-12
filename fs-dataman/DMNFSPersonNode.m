//
//  DMNFSPersonNode.m
//  fs-dataman
//
//  Created by Christopher Miller on 3/9/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMNFSPersonNode.h"

#import "DMNFSPersonNode_IndividualAssertionsDeleteWrapperOperation.h"
#import "DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation.h"

#import "WeakProxy.h"

#import "Console.h"

#import "NDService.h"
#import "NDService+FamilyTree.h"
#import "FSURLOperation.h"

@implementation DMNFSPersonNode {
    NSSet * _children;
    NSSet * _parents;
    NSSet * _spouses;
    __weak id _auth; // who locked this object?
}

@synthesize pid=_pid;
@synthesize me=_me;
@synthesize lock=_lock;
@synthesize children=_children;
@synthesize parents=_parents;
@synthesize spouses=_spouses;
@synthesize traversalState=_traversalState;
@synthesize writeState=_writeState;
@synthesize tearDownState=_tearDownState;

- (id)initWithPID:(NSString *)pid
{
    self = [self init];
    if (self) {
        _pid = pid;
    }
    return self;
}

- (BOOL)lockBeforeDate:(NSDate *)date byAuthority:(id)auth
{
    BOOL res = [self.lock lockBeforeDate:date];
    if (res) _auth = auth;
    return res;
}

- (void)unlock
{
    _auth = nil;
    [self.lock unlock];
}

#pragma mark Traversal

- (BOOL)isTraversed
{
    return self.spouses!=nil && self.parents!=nil && self.children!=nil;
}

- (void)__traverseCore_tryUnlockWithService:(NDService *)service globalNodeSet:(NSMutableSet *)allNodes recursive:(BOOL)recursive queue:(NSOperationQueue *)q lockOrigin:(id)lockOrigin
{
    if ([self isTraversed])
        self.traversalState = kTraverseState_Traversed;
    
    if (recursive) {
        NSArray * lockOriginStack;
        if ([lockOrigin isKindOfClass:[NSArray class]]) {
            lockOriginStack = [NSArray arrayWithObject:self];
            lockOriginStack = [lockOriginStack arrayByAddingObjectsFromArray:lockOrigin];
        }
        
        for (DMNFSPersonNode * child in self.children) {
            [q addOperation:[NSBlockOperation blockOperationWithBlock:^{
                if (![child isTraversed])
                    [child traverseTreeWithService:service globalNodeSet:allNodes recursive:recursive queue:q lockOrigin:lockOriginStack];
            }]];
        }
        for (DMNFSPersonNode * parent in self.parents) {
            [q addOperation:[NSBlockOperation blockOperationWithBlock:^{
                if (![parent isTraversed])
                    [parent traverseTreeWithService:service globalNodeSet:allNodes recursive:recursive queue:q lockOrigin:lockOriginStack];
            }]];
        }
        for (DMNFSPersonNode * spouse in self.spouses) {
            [q addOperation:[NSBlockOperation blockOperationWithBlock:^{
                if (![spouse isTraversed])
                    [spouse traverseTreeWithService:service globalNodeSet:allNodes recursive:recursive queue:q lockOrigin:lockOriginStack];
            }]];
        }
    }
}

- (void)traverseTreeWithService:(NDService *)service globalNodeSet:(NSMutableSet *)allNodes recursive:(BOOL)recursive queue:(NSOperationQueue *)q lockOrigin:(id)lockOrigin
{
    if (self.traversalState==kTraverseState_Traversed||self.traversalState==kTraverseState_Traversing)
        return;
    self.traversalState=kTraverseState_Traversing;

    NSMutableArray * operations = [[NSMutableArray alloc] initWithCapacity:3];
    FSURLOperation * oper;
    // Children
    oper =
    [service familyTreeOperationRelationshipOfReadType:NDFamilyTreeReadType.person forPerson:_pid relationshipType:NDFamilyTreeRelationshipType.child toPersons:nil withParameters:nil onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
        NSArray * children = [[response valueForKeyPath:@"persons.relationships.child.id"] firstObject];
        NSMutableSet * childNodes = [[NSMutableSet alloc] initWithCapacity:[children count]];
        @synchronized(allNodes) {
            for (NSString * pid in children) {
                // find any existing PID
                DMNFSPersonNode * newNode = [[DMNFSPersonNode alloc] initWithPID:pid];
                DMNFSPersonNode * existingNode = [allNodes member:newNode];
                if (recursive) {
                    if (!existingNode)
                        [allNodes addObject:newNode];
                    [childNodes addObject:[WeakProxy weakProxyWithObject:existingNode?:newNode]];
                } else
                    if (existingNode)
                        [childNodes addObject:[WeakProxy weakProxyWithObject:existingNode]];
                    else
                        [childNodes addObject:newNode];
            }
        }
        self.children = [childNodes copy];
        dm_PrintLn(@"%@ Added children: %@", _pid, [[[self.children valueForKey:@"pid"] allObjects] componentsJoinedByString:@", "]);
        
        [self __traverseCore_tryUnlockWithService:service globalNodeSet:allNodes recursive:recursive queue:q lockOrigin:lockOrigin];
        
    } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
        if ([resp statusCode]==404) {
            self.children=[NSSet set];
            dm_PrintLn(@"%@ has no children", self.pid);
        } else 
            dm_PrintURLOperationResponse(resp, payload, error);
    }];
    [operations addObject:oper];
    
    // Parents
    oper =
    [service familyTreeOperationRelationshipOfReadType:NDFamilyTreeReadType.person forPerson:_pid relationshipType:NDFamilyTreeRelationshipType.parent toPersons:nil withParameters:nil onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
        NSArray * parents = [[response valueForKeyPath:@"persons.relationships.parent.id"] firstObject];
        NSMutableSet * parentNodes = [[NSMutableSet alloc] initWithCapacity:[parents count]];
        @synchronized(allNodes) {
            for (NSString * pid in parents) {
                // find any existing PID
                DMNFSPersonNode * newNode = [[DMNFSPersonNode alloc] initWithPID:pid];
                DMNFSPersonNode * existingNode = [allNodes member:newNode];
                if (recursive) {
                    if (!existingNode)
                        [allNodes addObject:newNode];
                    [parentNodes addObject:[WeakProxy weakProxyWithObject:existingNode?:newNode]];
                } else
                    if (existingNode)
                        [parentNodes addObject:[WeakProxy weakProxyWithObject:existingNode]]; // weak reference
                    else
                        [parentNodes addObject:newNode]; // strong reference
            }
        }
        self.parents = [parentNodes copy];
        dm_PrintLn(@"%@ Added parents: %@", _pid, [[[self.parents valueForKey:@"pid"] allObjects] componentsJoinedByString:@", "]);
        
        [self __traverseCore_tryUnlockWithService:service globalNodeSet:allNodes recursive:recursive queue:q lockOrigin:lockOrigin];
        
    } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
        if ([resp statusCode]==404) {
            self.parents=[NSSet set];
            dm_PrintLn(@"%@ has no parents", self.pid);
        } else 
            dm_PrintURLOperationResponse(resp, payload, error);
    }];
    [operations addObject:oper];
    
    // Spouses
    oper =
    [service familyTreeOperationRelationshipOfReadType:NDFamilyTreeReadType.person forPerson:_pid relationshipType:NDFamilyTreeRelationshipType.spouse toPersons:nil withParameters:nil onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
        NSArray * spouses = [[response valueForKeyPath:@"persons.relationships.spouse.id"] firstObject];
        NSMutableSet * spouseNodes = [[NSMutableSet alloc] initWithCapacity:[spouses count]];
        @synchronized(allNodes) {
            for (NSString * pid in spouses) {
                // find any existing PID
                DMNFSPersonNode * newNode = [[DMNFSPersonNode alloc] initWithPID:pid];
                DMNFSPersonNode * existingNode = [allNodes member:newNode];
                if (recursive) {
                    if (!existingNode)
                        [allNodes addObject:newNode];
                    [spouseNodes addObject:[WeakProxy weakProxyWithObject:existingNode?:newNode]];
                } else
                    if (existingNode)
                        [spouseNodes addObject:[WeakProxy weakProxyWithObject:existingNode]]; // weak reference
                    else
                        [spouseNodes addObject:newNode]; // strong reference
            }
        }
        self.spouses = [spouseNodes copy];
        dm_PrintLn(@"%@ Added spouses: %@", _pid, [[[self.spouses valueForKey:@"pid"] allObjects] componentsJoinedByString:@", "]);
        
        [self __traverseCore_tryUnlockWithService:service globalNodeSet:allNodes recursive:recursive queue:q lockOrigin:lockOrigin];
        
    } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
        if ([resp statusCode]==404) {
            self.spouses=[NSSet set];
            dm_PrintLn(@"%@ has no spouses", self.pid);
        } else 
            dm_PrintURLOperationResponse(resp, payload, error);
    }];
    [operations addObject:oper];
    
    [q addOperations:operations waitUntilFinished:NO];
}

#pragma mark Tear Down

- (void)tearDownWithService:(NDService *)service queue:(NSOperationQueue *)q soft:(BOOL)soft
{
    [q addOperation:[DMNFSPersonNode_IndividualAssertionsDeleteWrapperOperation individualAssertionsDeleteWrapperOperationWithPersonNode:self service:service soft:soft]];
    for (DMNFSPersonNode * child in self.children)
        [q addOperation:[DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation relationshipAssertionsDeleteWrapperOperationFromPerson:self toPerson:child relationshipType:NDFamilyTreeRelationshipType.child service:service queue:q soft:soft]];
    for (DMNFSPersonNode * parent in self.parents)
        [q addOperation:[DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation relationshipAssertionsDeleteWrapperOperationFromPerson:self toPerson:parent relationshipType:NDFamilyTreeRelationshipType.parent service:service queue:q soft:soft]];
    for (DMNFSPersonNode * spouse in self.spouses)
        [q addOperation:[DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation relationshipAssertionsDeleteWrapperOperationFromPerson:self toPerson:spouse relationshipType:NDFamilyTreeRelationshipType.spouse service:service queue:q soft:soft]];
}

#pragma mark NSCopying

- (id)copy
{
    DMNFSPersonNode * n = [[[self class] alloc] initWithPID:_pid];
    n.lock = _lock;
    n.children = _children;
    n.parents = _parents;
    n.spouses = _spouses;
    return n;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self copy];
}

#pragma mark NSObject

- (id)init
{
    self = [super init];
    if (self) {
        _traversalState = kTraverseState_Untraversed;
        _tearDownState = kTearDownState_None;
        _writeState = kWriteState_Idle;
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (NSUInteger)hash
{
    return [_pid hash];
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[DMNFSPersonNode class]])
        return [self hash]==[object hash];
    else return NO;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@:%p PID:%@ Hash:%lu>", NSStringFromClass([self class]), (void *)self, _pid, [self hash]];
}

@end