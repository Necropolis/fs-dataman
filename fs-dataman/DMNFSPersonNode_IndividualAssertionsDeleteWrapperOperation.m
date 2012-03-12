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
    kReady,
    kCancelled,
    kExecuting,
    kFinished
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
        [self.personToKill addObserver:self forKeyPath:@"tearDownState" options:NSKeyValueObservingOptionNew context:NULL];
    }
    return self;
}

#pragma mark NSOperation

- (BOOL)isReady
{
    return self.personToKill.writeState==kWriteState_Idle && (self.personToKill.tearDownState&kTearDownState_IndividualAssertions)==0;
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
    
    // 1. Lock me
    self.personToKill.writeState = kWriteState_Active;
    
    [self willChangeValueForKey:@"isExecuting"];
    _state = kExecuting;
    [self didChangeValueForKey:@"isExecuting"];
        
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
        
        [self willChangeValueForKey:@"isFinished"];
        _state = kFinished;
        [self didChangeValueForKey:@"isFinished"];
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
    
    [self willChangeValueForKey:@"isFinished"];
    _state = kFinished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)_start_handleFailure:(NSHTTPURLResponse *)resp data:(NSData *)payload error:(NSError *)error
{
    dm_PrintLn(@"%@ Failed to perform deletion!", self.personToKill.pid);
    dm_PrintURLOperationResponse(resp, payload, error);
}

#pragma mark NSObject

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object==self.personToKill) {
        if ([keyPath isEqualToString:@"writeState"]||[keyPath isEqualToString:@"tearDownState"])
            [self didChangeValueForKey:@"isReady"]; // post a change notification
    } else {
        dm_PrintLn(@"Extraneous notification recieved.");
    }
}

- (void)dealloc
{
    [self.personToKill removeObserver:self forKeyPath:@"writeState"];
    [self.personToKill removeObserver:self forKeyPath:@"tearDownState"];
}

@end
