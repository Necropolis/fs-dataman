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
    kUnready=0,
    kReady=1<<1, // inidicates that it is not in a cancelled, executing, or finished state; does not track other preconditions!
    kExecuting=1<<2,
    kFinished=1<<3,
    kCancelled=1<<4
};

@interface DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation ()

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
        [self.toPerson addObserver:self forKeyPath:@"writeState" options:NSKeyValueObservingOptionNew context:NULL];
    }
    return self;
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

- (void)setIsReady:(__unused BOOL)isReady
{
    [self willChangeValueForKey:@"isReady"];
    if ([self isReady])
        _state = kReady;
    else
        _state = kUnready;
    [self didChangeValueForKey:@"isReady"];
}

- (BOOL)isReady
{
    return self.fromPerson.writeState == kWriteState_Idle && self.toPerson.writeState == kWriteState_Idle;
}

- (BOOL)isConcurrent
{
    return YES;
}

- (void)setIsExecuting:(BOOL)isExecuting
{
    [self willChangeValueForKey:@"isExecuting"];
    if (isExecuting)
        _state = kExecuting;
    else
        _state ^= kExecuting;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isExecuting
{
    return _state & kExecuting;
}

- (void)setIsFinished:(BOOL)isFinished
{
    if (isFinished) [self setIsExecuting:NO];
    [self willChangeValueForKey:@"isFinished"];
    if (isFinished)
        _state |= kFinished;
    else
        _state ^= kFinished;
    [self didChangeValueForKey:@"isFinished"];
    if (isFinished) {
        [self.fromPerson removeObserver:self forKeyPath:@"writeState"];
        [self.toPerson removeObserver:self forKeyPath:@"writeState"];
    }
}

- (BOOL)isFinished
{
    return _state & kFinished;
}

- (void)setIsCancelled:(BOOL)isCancelled
{
    [self willChangeValueForKey:@"isCancelled"];
    if (isCancelled)
        _state |= kCancelled;
    else
        _state ^= kCancelled;
    [self didChangeValueForKey:@"isCancelled"];
    if (isCancelled)
        [self setIsFinished:YES];
}

- (BOOL)isCancelled
{
    return _state & kCancelled;
}

- (void)start
{
    if ([self isCancelled]||[self isFinished])
        return;
    
    // 1. Lock fromPerson & toPerson
    self.fromPerson.writeState = kWriteState_Active;
    self.toPerson.writeState = kWriteState_Active;
    
    [self setIsExecuting:YES];
    
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
    NSDictionary * originalAssertions = [[[response valueForKeyPath:[NSString stringWithFormat:@"persons.relationships.%@.assertions", self.relationshipType]] firstObject] firstObject];
    NSNumber * version = [[[response valueForKeyPath:[NSString stringWithFormat:@"persons.relationships.%@.version", self.relationshipType]] firstObject] firstObject];
    
    dm_PrintLn(@"originalAssertions: %@", originalAssertions);
    dm_PrintLn(@"version: %@", version);
    
    
    self.fromPerson.writeState = kWriteState_Idle;
    self.toPerson.writeState = kWriteState_Idle;
    
    [self setIsFinished:YES];
}

- (void)_start_respondToRelationshipUpdate:(id)response
{
    
}

- (void)_start_handleFailure:(NSHTTPURLResponse *)resp payload:(NSData *)payload error:(NSError *)error
{
    if (resp.statusCode == 503) {
        dm_PrintLn(@"%@ to %@ %@ has been throttled; sleeping for 20 seconds, then trying again.", self.fromPerson.pid, self.relationshipType, self.toPerson.pid);
        [NSThread sleepForTimeInterval:20.0f];
        [self start];
    } else {
        dm_PrintLn(@"%@ to %@ %@ failed to perform deletion", self.fromPerson.pid, self.relationshipType, self.toPerson.pid);
        dm_PrintURLOperationResponse(resp, payload, error);
        
        self.fromPerson.writeState = kWriteState_Idle;
        self.toPerson.writeState = kWriteState_Idle;
        
        [self setIsFinished:YES];
    }
}

#pragma mark NSObject

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object==self.fromPerson || object==self.toPerson) {
        // check to see if the assertion should still exist
        // this is an easy way to invalidate this operation before it hits the queue
        [self setIsReady:[self isReady]];
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
    
    return [NSString stringWithFormat:@"<%@:%p from:%@ to:%@ state:%@ isReady:%@ isExecuting:%@ isFinished:%@ isCancelled:%@>", NSStringFromClass([self class]), (void *)self, self.fromPerson.pid, self.toPerson.pid, state, [self isReady]?@"YES":@"NO", [self isExecuting]?@"YES":@"NO", [self isFinished]?@"YES":@"NO", [self isCancelled]?@"YES":@"NO"];
}

- (void)dealloc
{
    if (![self isFinished]) {
        [self.fromPerson removeObserver:self forKeyPath:@"writeState"];
        [self.toPerson removeObserver:self forKeyPath:@"writeState"];
    }
}

@end
