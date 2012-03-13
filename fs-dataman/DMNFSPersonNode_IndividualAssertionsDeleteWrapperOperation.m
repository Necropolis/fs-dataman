//
//  DMNFSPersonNode_IndividualAssertionsDeleteWrapperOperation.m
//  fs-dataman
//
//  Created by Christopher Miller on 3/12/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMNFSPersonNode_IndividualAssertionsDeleteWrapperOperation.h"

#import "DMNFSPersonNode.h"
#import "Console.h"

#import "NDService.h"
#import "NDService+FamilyTree.h"
#import "FSURLOperation.h"

enum DMNFSPersonNode_IndividualAssertionsDeleteWrapperOperation_State {
    kUnready=0,
    kReady=1<<1,
    kCancelled=1<<2,
    kExecuting=1<<3,
    kFinished=1<<4
};

@interface DMNFSPersonNode_IndividualAssertionsDeleteWrapperOperation ()

- (void)_start_returnFromReadRequest:(id)response;
- (void)_start_returnFromDeleteRequest:(id)response;
- (void)_start_handleFailure:(NSHTTPURLResponse *)resp data:(NSData *)payload error:(NSError *)error;

@end

@implementation DMNFSPersonNode_IndividualAssertionsDeleteWrapperOperation {
    enum DMNFSPersonNode_IndividualAssertionsDeleteWrapperOperation_State _state;
}

@synthesize personToKill=_personToKill;
@synthesize service=_service;
@synthesize soft=_soft;

+ (id)individualAssertionsDeleteWrapperOperationWithPersonNode:(DMNFSPersonNode *)node service:(NDService *)service soft:(BOOL)soft
{
    DMNFSPersonNode_IndividualAssertionsDeleteWrapperOperation * wrapperOperation = [[DMNFSPersonNode_IndividualAssertionsDeleteWrapperOperation alloc] initWithPersonNode:node service:service soft:soft];
    return wrapperOperation;
}

- (id)initWithPersonNode:(DMNFSPersonNode *)node service:(NDService *)service soft:(BOOL)soft
{
    self = [super init];
    if (self) {
        _personToKill = node;
        _service = service;
        _soft = soft;
        // set up to recieve notifications
        [self.personToKill addObserver:self forKeyPath:@"writeState" options:NSKeyValueObservingOptionNew context:NULL];
    }
    return self;
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
    return self.personToKill.writeState==kWriteState_Idle;
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
    if (isFinished)
        [self setIsExecuting:NO];
    [self willChangeValueForKey:@"isFinished"];
    if (isFinished)
        _state |= kFinished;
    else
        _state ^= kFinished;
    [self didChangeValueForKey:@"isFinished"];
    if (isFinished)
        [self.personToKill removeObserver:self forKeyPath:@"writeState"];
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
    if (isCancelled)
        [self setIsFinished:YES];
    [self didChangeValueForKey:@"isCancelled"];
}

- (BOOL)isCancelled
{
    return _state & kCancelled;
}

- (void)start
{
    if ([self isCancelled]||[self isFinished]) return;
    
    // 1. Lock me
    self.personToKill.writeState = kWriteState_Active;
    
    [self setIsExecuting:YES];
        
    // 2. Read me from the API
    FSURLOperation * oper =
    [self.service familyTreeOperationReadPersons:self.personToKill.pid withParameters:NDFamilyTreeAllPersonReadValues() onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
        dm_PrintLn(@"%@ Deletion Progress: Read all assertions", self.personToKill.pid);
        [self _start_returnFromReadRequest:response];
    } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
        [self _start_handleFailure:resp data:payload error:error];
    }];
    [self.service.operationQueue addOperation:oper];
}

- (void)_start_returnFromReadRequest:(id)response
{
    NSDictionary * person = [[response valueForKey:@"persons"] firstObject];
    NSMutableDictionary * deleteAllAssertions = [NSMutableDictionary dictionaryWithCapacity:[NDFamilyTreeAllAssertionTypes() count]];
    for (NSString * type in NDFamilyTreeAllAssertionTypes()) {
        NSArray * originalAssertions = [person valueForKeyPath:[NSString stringWithFormat:@"assertions.%@", type]];
        [deleteAllAssertions setObject:[NSMutableArray arrayWithCapacity:[originalAssertions count]] forKey:type];
        for (NSDictionary * assertion in originalAssertions) {
            NSDictionary * deleteAssertion = [NSDictionary dictionaryWithObjectsAndKeys:
                                              @"Delete", @"action",
                                              [NSDictionary dictionaryWithObject:[assertion valueForKeyPath:@"value.id"] forKey:@"id"], @"value", nil];
            [[deleteAllAssertions objectForKey:type] addObject:deleteAssertion];
        }
    }
    
    if (self.soft) {
        self.personToKill.tearDownState |= kTearDownState_IndividualAssertions;
        self.personToKill.writeState = kWriteState_Idle;
        
        dm_PrintLn(@"%@ Deletion Progress: Would have dispatched request to remove\n"
                   @"                            assertions, but running in SOFT mode", self.personToKill.pid);
        
        [self setIsFinished:YES];
    } else {
        // chuck if off to the queue
        FSURLOperation * oper =
        [self.service familytreeOperationPersonUpdate:self.personToKill.pid assertions:deleteAllAssertions onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
            dm_PrintLn(@"%@ Deletion Progress: Deleted all assertions", self.personToKill.pid);
            [self _start_returnFromDeleteRequest:response];
        } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
            [self _start_handleFailure:resp data:payload error:error];
        } withTargetThread:nil];
        [self.service.operationQueue addOperation:oper];
    }
}

- (void)_start_returnFromDeleteRequest:(id)response
{
    self.personToKill.tearDownState |= kTearDownState_IndividualAssertions;
    self.personToKill.writeState = kWriteState_Idle;
    
    [self setIsFinished:YES];
}

- (void)_start_handleFailure:(NSHTTPURLResponse *)resp data:(NSData *)payload error:(NSError *)error
{
    dm_PrintLn(@"%@ Failed to perform deletion!", self.personToKill.pid);
    dm_PrintURLOperationResponse(resp, payload, error);
    
    self.personToKill.writeState = kWriteState_Idle;
    
    [self setIsFinished:YES];
}

#pragma mark NSObject

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object==self.personToKill)
        [self setIsReady:[self isReady]];
    else
        dm_PrintLn(@"Extraneous notification recieved.");
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@:%p PID:%@ isReady:%@ isExecuting:%@ isFinished:%@ isCancelled:%@>",
            NSStringFromClass([self class]), (void *)self, self.personToKill.pid,
            [self isReady]?@"YES":@"NO",
            [self isExecuting]?@"YES":@"NO",
            [self isFinished]?@"YES":@"NO",
            [self isCancelled]?@"YES":@"NO"];
}

- (void)dealloc
{
    if (![self isFinished])
        [self.personToKill removeObserver:self forKeyPath:@"writeState"];
}

@end
