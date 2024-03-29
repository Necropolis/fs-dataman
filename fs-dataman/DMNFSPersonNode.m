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
}

@synthesize pid=_pid;
@synthesize me=_me;
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

#pragma mark Traversal

- (BOOL)isTraversed
{
    return self.spouses!=nil && self.parents!=nil && self.children!=nil;
}

- (void)__traverseCore_tryUnlockWithService:(NDService *)service globalNodeSet:(NSMutableSet *)allNodes recursive:(BOOL)recursive queue:(NSOperationQueue *)q
{
    if ([self isTraversed])
        self.traversalState = kTraverseState_Traversed;
    
    if (recursive) {
        for (DMNFSPersonNode * child in self.children) {
            [q addOperation:[NSBlockOperation blockOperationWithBlock:^{
                if (![child isTraversed])
                    [child traverseTreeWithService:service globalNodeSet:allNodes recursive:recursive queue:q];
            }]];
        }
        for (DMNFSPersonNode * parent in self.parents) {
            [q addOperation:[NSBlockOperation blockOperationWithBlock:^{
                if (![parent isTraversed])
                    [parent traverseTreeWithService:service globalNodeSet:allNodes recursive:recursive queue:q];
            }]];
        }
        for (DMNFSPersonNode * spouse in self.spouses) {
            [q addOperation:[NSBlockOperation blockOperationWithBlock:^{
                if (![spouse isTraversed])
                    [spouse traverseTreeWithService:service globalNodeSet:allNodes recursive:recursive queue:q];
            }]];
        }
    }
}

- (void)_traverseTreeWithService__childTraversal:(NDService *)service _globalNodeSet:(NSMutableSet *)allNodes _recursive:(BOOL)recursive _queue:(NSOperationQueue *)q
{
    FSURLOperation * oper =
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
        
        [self __traverseCore_tryUnlockWithService:service globalNodeSet:allNodes recursive:recursive queue:q];
        
    } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
        if ([resp statusCode]==404) {
            self.children=[NSSet set];
            dm_PrintLn(@"%@ has no children", self.pid);
        } else if (resp.statusCode == 503) {
            dm_PrintLn(@"%@ child read was throttled; waiting 20 seconds, then trying again.", self.pid);
            [NSThread sleepForTimeInterval:20.0f];
            [self _traverseTreeWithService__childTraversal:service _globalNodeSet:allNodes _recursive:recursive _queue:q];
        } else 
            dm_PrintURLOperationResponse(resp, payload, error);
    }];
    [q addOperation:oper];
}

- (void)_traverseTreeWithService__parentTraversal:(NDService *)service _globalNodeSet:(NSMutableSet *)allNodes _recursive:(BOOL)recursive _queue:(NSOperationQueue *)q
{
    FSURLOperation * oper =
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
        
        [self __traverseCore_tryUnlockWithService:service globalNodeSet:allNodes recursive:recursive queue:q];
        
    } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
        if ([resp statusCode]==404) {
            self.parents=[NSSet set];
            dm_PrintLn(@"%@ has no parents", self.pid);
        } else if (resp.statusCode == 503) {
            dm_PrintLn(@"%@ parent read was throttled; waiting 20 seconds, then trying again.", self.pid);
            [NSThread sleepForTimeInterval:20.0f];
            [self _traverseTreeWithService__parentTraversal:service _globalNodeSet:allNodes _recursive:recursive _queue:q];
        } else 
            dm_PrintURLOperationResponse(resp, payload, error);
    }];
    [q addOperation:oper];
}

- (void)_traverseTreeWithService__spouseTraversal:(NDService *)service _globalNodeSet:(NSMutableSet *)allNodes _recursive:(BOOL)recursive _queue:(NSOperationQueue *)q
{
    FSURLOperation * oper =
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
        
        [self __traverseCore_tryUnlockWithService:service globalNodeSet:allNodes recursive:recursive queue:q];
        
    } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
        if ([resp statusCode]==404) {
            self.spouses=[NSSet set];
            dm_PrintLn(@"%@ has no spouses", self.pid);
        } else if (resp.statusCode == 503) {
            dm_PrintLn(@"%@ spouse read was throttled; waiting 20 seconds, then trying again.", self.pid);
            [NSThread sleepForTimeInterval:20.0f];
            [self _traverseTreeWithService__spouseTraversal:service _globalNodeSet:allNodes _recursive:recursive _queue:q];
        } else 
            dm_PrintURLOperationResponse(resp, payload, error);
    }];
    [q addOperation:oper];
}

- (void)traverseTreeWithService:(NDService *)service globalNodeSet:(NSMutableSet *)allNodes recursive:(BOOL)recursive queue:(NSOperationQueue *)q
{
    if (self.traversalState==kTraverseState_Traversed||self.traversalState==kTraverseState_Traversing)
        return;
    self.traversalState=kTraverseState_Traversing;

    [self _traverseTreeWithService__childTraversal:service _globalNodeSet:allNodes _recursive:recursive _queue:q];
    [self _traverseTreeWithService__parentTraversal:service _globalNodeSet:allNodes _recursive:recursive _queue:q];
    [self _traverseTreeWithService__spouseTraversal:service _globalNodeSet:allNodes _recursive:recursive _queue:q];    
}

#pragma mark Tear Down

- (BOOL)_tearDownWithService_shouldAddOperationFromNode:(DMNFSPersonNode *)fromNode toNode:(DMNFSPersonNode *)toNode relType:(NSString *)relType operations:(NSArray *)operations
{
    NSArray * relevantOperations = [operations filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSOperation * unknownOperation, NSDictionary *bindings) {
        if (![unknownOperation isKindOfClass:[DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation class]]) return NO;
        DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation * knownOperation = (DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation *)unknownOperation;
        if (![knownOperation.relationshipType isEqual:relType]) return NO;
        NSSet * nodes = [NSSet setWithObjects:knownOperation.fromPerson, knownOperation.toPerson, nil];
        if ([nodes member:fromNode] && [nodes member:toNode]) return YES;
        else return NO;
    }]];
    if ([relevantOperations count]>0) return NO;
    else return YES;
}

- (NSArray *)tearDownWithService:(NDService *)service queue:(NSOperationQueue *)q allOperations:(NSArray *)allOperations soft:(BOOL)soft
{
    NSMutableArray * operations = [[NSMutableArray alloc] init];
    [operations addObject:[DMNFSPersonNode_IndividualAssertionsDeleteWrapperOperation individualAssertionsDeleteWrapperOperationWithPersonNode:self service:service soft:soft]];
    for (DMNFSPersonNode * child in self.children)
        if (([child class]==[WeakProxy class]&&[((WeakProxy *)child) object])||[child class]!=[WeakProxy class])
            if ([self _tearDownWithService_shouldAddOperationFromNode:self toNode:child relType:NDFamilyTreeRelationshipType.child operations:allOperations])
                [operations addObject:[DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation relationshipAssertionsDeleteWrapperOperationFromPerson:self toPerson:child relationshipType:NDFamilyTreeRelationshipType.child service:service queue:q soft:soft]];
    for (DMNFSPersonNode * parent in self.parents)
        if (([parent class]==[WeakProxy class]&&[((WeakProxy *)parent) object])||[parent class]!=[WeakProxy class])
            if ([self _tearDownWithService_shouldAddOperationFromNode:self toNode:parent relType:NDFamilyTreeRelationshipType.parent operations:allOperations])
                [operations addObject:[DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation relationshipAssertionsDeleteWrapperOperationFromPerson:self toPerson:parent relationshipType:NDFamilyTreeRelationshipType.parent service:service queue:q soft:soft]];
    for (DMNFSPersonNode * spouse in self.spouses)
        if (([spouse class]==[WeakProxy class]&&[((WeakProxy *)spouse) object])||[spouse class]!=[WeakProxy class])
            if ([self _tearDownWithService_shouldAddOperationFromNode:self toNode:spouse relType:NDFamilyTreeRelationshipType.spouse operations:allOperations])
                [operations addObject:[DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation relationshipAssertionsDeleteWrapperOperationFromPerson:self toPerson:spouse relationshipType:NDFamilyTreeRelationshipType.spouse service:service queue:q soft:soft]];
    return operations;
}

#pragma mark NSCopying

- (id)copy
{
    DMNFSPersonNode * n = [[[self class] alloc] initWithPID:_pid];
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
