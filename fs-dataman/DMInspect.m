//
//  DMInspect.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 FSDEV. All rights reserved.
//

#import "DMInspect.h"

#import "Console.h"

#import "NDService.h"
#import "NDService+FamilyTree.h"

#import "FSURLOperation.h"

@interface DMInspect (__PRIVATE__)

- (void)relationshipTraverseForId:(NSString*)recordId;

@end

@implementation DMInspect {
    NSMutableSet* _collectedIds;
    NSString* _myId;
    NSString* _objectIdFileLocation;
}

@synthesize objectIds=_objectIds;
@synthesize gedcom=_gedcom;

- (void)processArgs
{
    if ([self.arguments count] < 1) {
        dm_PrintLn(@"No output file or GEDCOM exemplar specified. I'm going to stop now before I hurt myself.");
        exit(-1);
    } else if ([self.arguments count] > 2) {
        dm_PrintLn(@"More arguments than necessary. I'm confused, so I'm going to stop now before I hurt myself.");
        exit(-1);
    }
    
    _objectIdFileLocation = [[self.arguments objectAtIndex:0] stringByExpandingTildeInPath];
    if ([self.arguments count] == 2) { dm_PrintLn(@"Unimplemented feature: compare to GEDCOM."); exit(-1); }
    
    [[NSFileManager defaultManager] createFileAtPath:_objectIdFileLocation
                                            contents:[NSData data]
                                          attributes:nil];
    
    self.objectIds = [NSFileHandle fileHandleForWritingAtPath:_objectIdFileLocation];
    [self.objectIds truncateFileAtOffset:0]; // ensure that the darn thing is empty!
}

- (NSString*)verbHeader
{
    return [NSString stringWithFormat:@"INSPECT with ofile: %@", _objectIdFileLocation];
}

- (void)run
{
    // traverse the effing tree
    __block NSDictionary* me=nil;
    FSURLOperation* getMe =
    [self.service familyTreeOperationReadPersons:[NSArray array] withParameters:nil onSuccess:^(NSHTTPURLResponse* resp, id response, NSData* payload) {
        me = response;
    } onFailure:^(NSHTTPURLResponse* resp, NSData* payload, NSError* error) {
        dm_PrintLn(@"Failed to get current user in the tree!");
        dm_PrintURLOperationResponse(resp, payload, error);
        exit(-1);
    }];
    [self.service.operationQueue addOperation:getMe];
    [getMe waitUntilFinished];
    
    _myId = [[me valueForKeyPath:@"persons.id"] firstObject];

    dm_PrintLn(@"My ID: %@", _myId);
    
    _collectedIds = [[NSMutableSet alloc] init];
    
    [self relationshipTraverseForId:_myId];
    
    [self.service.operationQueue waitUntilAllOperationsAreFinished];
    
    NSDictionary* d=[[NSDictionary alloc] initWithObjectsAndKeys:[_collectedIds allObjects], @"persons", nil];
    
    NSError* err=nil;
    NSData* __data=[NSJSONSerialization dataWithJSONObject:d options:NSJSONWritingPrettyPrinted error:&err];
    
    [self.objectIds writeData:__data];
    dm_PrintLn(@"Wrote output as JSON to %@", _objectIdFileLocation);
}

- (void)relationshipTraverseForId:(NSString *)recordId
{
    FSURLOperation* parentsRead =
    [self.service familyTreeOperationRelationshipOfReadType:NDFamilyTreeReadType.person
                                                  forPerson:recordId
                                           relationshipType:NDFamilyTreeRelationshipType.parent
                                                  toPersons:nil
                                             withParameters:nil
                                                  onSuccess:^(NSHTTPURLResponse* resp, id response, NSData* payload) {
                                                      dm_PrintLn(@"[RELATIONSHIP:PARENT] Read Success for %@", recordId);
                                                      NSArray* personIds = [[response valueForKeyPath:@"persons.relationships.parent.id"] firstObject];
                                                      for (NSString* __id in personIds) {
                                                          if ([_collectedIds containsObject:__id]||[__id isEqualToString:_myId]) continue;
                                                          [_collectedIds addObject:__id];
                                                          [self relationshipTraverseForId:__id];
                                                      }
                                                  } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
                                                      if ([resp statusCode]==404) {
                                                          // it just didn't find anything. That's OK.
                                                      } else {                                                          
                                                          dm_PrintLn(@"Failed to read relationship");
                                                          dm_PrintURLOperationResponse(resp, payload, error);
                                                          exit(-1);
                                                      }
                                                  }];
    FSURLOperation* spousesRead =
    [self.service familyTreeOperationRelationshipOfReadType:NDFamilyTreeReadType.person
                                                  forPerson:recordId
                                           relationshipType:NDFamilyTreeRelationshipType.spouse
                                                  toPersons:nil
                                             withParameters:nil
                                                  onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
                                                      dm_PrintLn(@"[RELATIONSHIP:SPOUSE] Read Success for %@", recordId);
                                                      NSArray* personIds = [[response valueForKeyPath:@"persons.relationships.spouse.id"] firstObject];
                                                      for (NSString* __id in personIds) {
                                                          if ([_collectedIds containsObject:__id]||[__id isEqualToString:_myId]) continue;
                                                          [_collectedIds addObject:__id];
                                                          [self relationshipTraverseForId:__id];
                                                      }
                                                  }
                                                  onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
                                                      if ([resp statusCode]==404) {
                                                          // it just didn't find anything. That's OK.
                                                      } else {
                                                          dm_PrintLn(@"Failed to read relationship");
                                                          dm_PrintURLOperationResponse(resp, payload, error);
                                                          exit(-1);
                                                      }
                                                  }];
    FSURLOperation* childRead =
    [self.service familyTreeOperationRelationshipOfReadType:NDFamilyTreeReadType.person
                                                  forPerson:recordId
                                           relationshipType:NDFamilyTreeRelationshipType.child
                                                  toPersons:nil
                                             withParameters:nil
                                                  onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
                                                      dm_PrintLn(@"[RELATIONSHIP:CHILD]  Read Success for %@", recordId);
                                                      NSArray* personIds = [[response valueForKeyPath:@"persons.relationships.child.id"] firstObject];
                                                      for (NSString* __id in personIds) {
                                                          if ([_collectedIds containsObject:__id]||[__id isEqualToString:_myId]) continue;
                                                          [_collectedIds addObject:__id];
                                                          [self relationshipTraverseForId:__id];
                                                      }
                                                  } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
                                                      if ([resp statusCode]==404) {
                                                          // it just didn't find anything. That's OK.
                                                      } else {
                                                          dm_PrintLn(@"Failed to read relationship");
                                                          dm_PrintURLOperationResponse(resp, payload, error);
                                                          exit(-1);
                                                      }
                                                  }];
    
    [self.service.operationQueue addOperation:parentsRead];
    [self.service.operationQueue addOperation:spousesRead];
    [self.service.operationQueue addOperation:childRead];
}

@end
