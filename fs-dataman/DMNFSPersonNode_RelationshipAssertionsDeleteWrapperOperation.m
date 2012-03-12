//
//  DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation.m
//  fs-dataman
//
//  Created by Christopher Miller on 3/12/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation.h"

#import "DMNFSPersonNode.h"
#import "WeakProxy.h"
#import "Console.h"

#import "NDService.h"
#import "NDService+FamilyTree.h"
#import "FSURLOperation.h"

enum DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation_State {
    kReady, // inidicates that it is not in a cancelled, executing, or finished state; does not track other preconditions!
    kCancelled,
    kExecuting,
    kFinished
};

@interface DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation ()

- (BOOL)_stateSpecificTeardownReadiness;
- (BOOL)_hasFromPersonInToPersonsSet;

- (void)_start_respondToAssertionRead:(id)response;
- (void)_start_respondToRelationshipUpdate:(id)response;
- (void)_start_handleFailure:(NSHTTPURLResponse *)resp payload:(NSData *)payload error:(NSError *)error;

@end

@implementation DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation {
    enum DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation_State _state;
}

BOOL _stateSpecificTeardownReadiness(void);

@synthesize fromPerson=_fromPerson;
@synthesize toPerson=_toPerson;
@synthesize relationshipType=_relationshipType;
@synthesize service=_service;
@synthesize q=_q;
@synthesize soft=_soft;

+ (id)relationshipAssertionsDeleteWrapperOperationFromPerson:(DMNFSPersonNode *)fromPerson toPerson:(DMNFSPersonNode *)toPerson relationshipType:(NSString *)relationshipType service:(NDService *)service queue:(NSOperationQueue *)q soft:(BOOL)soft
{
    DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation * wrapper = [[[self class] alloc] initWithFromPerson:fromPerson toPerson:toPerson relationshipType:relationshipType service:service queue:q soft:soft];
    return wrapper;
}

- (id)initWithFromPerson:(DMNFSPersonNode *)fromPerson toPerson:(DMNFSPersonNode *)toPerson relationshipType:(NSString *)relationshipType service:(NDService *)service queue:(NSOperationQueue *)q soft:(BOOL)soft
{
    self = [super init];
    if (self) {
        _fromPerson = [fromPerson class]==[WeakProxy class]?((WeakProxy *)fromPerson).object:fromPerson;
        _toPerson = [toPerson class]==[WeakProxy class]?((WeakProxy *)toPerson).object:toPerson;
        _relationshipType = relationshipType;
        _service = service;
        _q = q;
        _soft = soft;
        _state = kReady;
        // set up to receive notifications
        [self.fromPerson addObserver:self forKeyPath:@"writeState" options:NSKeyValueObservingOptionNew context:NULL];
        [self.fromPerson addObserver:self forKeyPath:@"tearDownState" options:NSKeyValueObservingOptionNew context:NULL];
        [self.toPerson addObserver:self forKeyPath:@"writeState" options:NSKeyValueObservingOptionNew context:NULL];
        [self.toPerson addObserver:self forKeyPath:@"tearDownState" options:NSKeyValueObservingOptionNew context:NULL];
    }
    return self;
}

- (BOOL)_stateSpecificTeardownReadiness
{
#ifdef DEBUG
    NSAssert([NDFamilyTreeAllRelationshipTypes() containsObject:self.relationshipType], @"Unknown relationship type.");
#endif
    if ([self.relationshipType isEqual:NDFamilyTreeRelationshipType.child])
        return (self.fromPerson.tearDownState & kTearDownState_ChildAssertions) == kTearDownState_None
                                                                &&
                (self.toPerson.tearDownState & kTearDownState_ChildAssertions) == kTearDownState_None;
    else if ([self.relationshipType isEqual:NDFamilyTreeRelationshipType.parent])
        return (self.fromPerson.tearDownState & kTearDownState_ParentAssertions) == kTearDownState_None
                                                                &&
                (self.toPerson.tearDownState & kTearDownState_ParentAssertions) == kTearDownState_None;
    else // spouse
        return (self.fromPerson.tearDownState & kTearDownState_SpouseAssertions) == kTearDownState_None
                                                                &&
                (self.fromPerson.tearDownState & kTearDownState_SpouseAssertions) == kTearDownState_None;
}

- (BOOL)_hasFromPersonInToPersonsSet
{
    if ([self.relationshipType isEqual:NDFamilyTreeRelationshipType.child])
        return !![self.toPerson.parents member:self.fromPerson];
    else if ([self.relationshipType isEqual:NDFamilyTreeRelationshipType.parent])
        return !![self.toPerson.children member:self.fromPerson];
    else if ([self.relationshipType isEqual:NDFamilyTreeRelationshipType.spouse])
        return !![self.toPerson.spouses member:self.fromPerson];
    else {
        dm_PrintLn(@"Unknown relationship type");
        return NO;
    }
}

#pragma mark NSOperation

- (BOOL)isReady
{
    return self.fromPerson.writeState == kWriteState_Idle && self.toPerson.writeState == kWriteState_Idle && [self _stateSpecificTeardownReadiness] && _state == kReady;
}

- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isExecuting
{
    return _state == kExecuting;
}

- (BOOL)isFinished
{
    return _state == kFinished;
}

- (BOOL)isCancelled
{
    return _state == kCancelled;
}

- (void)start
{
    if ([self isCancelled]||[self isFinished]) return;
    
    // 1. Lock fromPerson & toPerson
    self.fromPerson.writeState = kWriteState_Active;
    self.toPerson.writeState = kWriteState_Active;
    
    [self willChangeValueForKey:@"isExecuting"];
    _state = kExecuting;
    [self didChangeValueForKey:@"isExecuting"];
    
    // 2. Get all assertions
    FSURLOperation * oper =
    [self.service familyTreeOperationRelationshipOfReadType:NDFamilyTreeReadType.person forPerson:self.fromPerson.pid relationshipType:self.relationshipType toPersons:self.toPerson.pid withParameters:NDFamilyTreeAllRelationshipReadValues() onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
        dm_PrintLn(@"%@ to %@ %@ Deletion Status: Retrieved Assertions", self.fromPerson.pid, self.relationshipType, self.toPerson.pid);
        [self _start_respondToAssertionRead:response];
    } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
        [self _start_handleFailure:resp payload:payload error:error];
    }];
    [self.q addOperation:oper];
}

- (void)_start_respondToAssertionRead:(id)response
{
    dm_PrintLn(@"response: %@", response);
    
    
    
    
    self.fromPerson.writeState = kWriteState_Idle;
    self.toPerson.writeState = kWriteState_Idle;
    
    [self willChangeValueForKey:@"isFinished"];
    _state = kFinished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)_start_respondToRelationshipUpdate:(id)response
{
    
}

- (void)_start_handleFailure:(NSHTTPURLResponse *)resp payload:(NSData *)payload error:(NSError *)error
{
    dm_PrintLn(@"%@ to %@ %@ failed to perform deletion");
    dm_PrintURLOperationResponse(resp, payload, error);
}

#pragma mark NSObject

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ((object==self.fromPerson || object==self.toPerson) && _state == kReady) {
        // check to see if the assertion should still exist
        // this is an easy way to invalidate this operation before it hits the queue
        
        if (![self _hasFromPersonInToPersonsSet]) {
            [self cancel];
            _state = kCancelled;
        } else if (_state == kCancelled) {
            dm_PrintLn(@"State transition unavailable to revalidate deletion operation from %@ to %@ %@", self.fromPerson.pid, self.relationshipType, self.toPerson.pid);
        }
        
        if ([self isReady])
            [self didChangeValueForKey:@"isReady"];
        
    } else
        dm_PrintLn(@"Extraneous notification recieved from object %@; expecting either %@ or %@.", object, self.fromPerson, self.toPerson);
}

- (NSString *)description
{
    NSString * state;
    if (_state == kReady) state = @"Ready";
    else if (_state == kCancelled) state = @"Cancelled";
    else if (_state == kExecuting) state = @"Executing";
    else state = @"Finished";
    
    return [NSString stringWithFormat:@"<%@:%p from:%@ to:%@ state:%@>", NSStringFromClass([self class]), (void *)self, self.fromPerson.pid, self.toPerson.pid, state];
}

- (void)dealloc
{
    [self.fromPerson removeObserver:self forKeyPath:@"writeState"];
    [self.fromPerson removeObserver:self forKeyPath:@"tearDownState"];
    [self.toPerson removeObserver:self forKeyPath:@"writeState"];
    [self.toPerson removeObserver:self forKeyPath:@"tearDownState"];
}

@end
