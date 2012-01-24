//
//  DMUnlink.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/19/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMUnlink.h"

#import "Console.h"

#import "NDService.h"
#import "NDService+FamilyTree.h"
#import "FSURLOperation.h"
#import "NSData+StringValue.h"

@implementation DMUnlink {
    NSString* __ifilelocation;
}

@synthesize objectIdsFile=_objectIdsFile;

- (void)processArgs
{
    if ([self.arguments count]!=1) {
        dm_PrintLn(@"Incorrect number of arguments.");
        exit(-1);
    }
    
    __ifilelocation = [[self.arguments objectAtIndex:0] stringByExpandingTildeInPath];
    NSFileManager* _mgr=[NSFileManager defaultManager];
    if ([_mgr fileExistsAtPath:__ifilelocation]&&[_mgr isReadableFileAtPath:__ifilelocation]) {
        self.objectIdsFile = [NSFileHandle fileHandleForReadingAtPath:__ifilelocation];
        NSAssert(_objectIdsFile!=nil,@"Seriously, how can this freaking happen?");
    } else {
        dm_PrintLn(@"I cannot open the input file for reading. Dude, this is totally not cool. I'm gunna quit now.");
        exit(-1);
    }
    // all should be well in Zion, right?
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"UNLINK as parents the ids from file %@ from current the user", __ifilelocation];
}

- (void)run
{
    NSError* err=nil;
    NSDictionary* ids = [NSJSONSerialization JSONObjectWithData:[_objectIdsFile readDataToEndOfFile] options:0 error:&err];
    if (err) {
        dm_PrintLn(@"Experienced JSON parse error: %@", err);
        exit(-1);
    }
    
    [self getMe];
    NSString* _myId = [[self.me valueForKeyPath:@"persons.id"] firstObject];
    __block NSDictionary* dict = nil;
    
    FSURLOperation* _oper =
    [self.service familyTreeOperationRelationshipOfReadType:NDFamilyTreeReadType.person
                                                  forPerson:_myId
                                           relationshipType:NDFamilyTreeRelationshipType.parent
                                                  toPersons:[ids valueForKey:@"persons"]
                                             withParameters:[NSDictionary dictionaryWithObjectsAndKeys:NDFamilyTreeReadRequestValue.all, NDFamilyTreeReadRequestParameter.characteristics, NDFamilyTreeReadRequestValue.all, NDFamilyTreeReadRequestParameter.assertions, NDFamilyTreeReadRequestValue.all, NDFamilyTreeReadRequestParameter.values, nil]
                                                  onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
                                                      dict = response;
                                                  }
                                                  onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
                                                      dm_PrintURLOperationResponse(resp, payload, error);
                                                  }];
    [self.service.operationQueue addOperation:_oper];
    [self.service.operationQueue waitUntilAllOperationsAreFinished];
    
    NSMutableArray* resp = [NSMutableArray arrayWithCapacity:2];
    for (id _i in [dict valueForKeyPath:@"persons"])
        [resp addObject:_i];
    
    for (NSDictionary* _i in resp) {
        id parents = [_i valueForKeyPath:@"relationships.parent"];
        for (NSDictionary* parent in parents) {
            for (NSString* assertionType in [[parent valueForKey:@"assertions"] allKeys]) {
                for (NSDictionary* assertion in [[parent valueForKey:@"assertions"] objectForKey:assertionType]) {
                    FSURLOperation* oper = // note that this may fail horribly for multiple assertions if the deletion causes a version bump.
                    [self.service familyTreeOperationRelationshipDeleteFromPerson:_myId relationshipType:NDFamilyTreeRelationshipType.parent toPerson:[parent valueForKey:@"id"] relationshipVersion:[parent valueForKey:@"version"] assertionType:assertionType assertion:assertion onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
                        dm_PrintLn(@"Deleted relationship assertion between %@ and %@", _myId, [parent valueForKey:@"id"]);
                    } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
                        dm_PrintURLOperationResponse(resp, payload, error);
                    }];
                    dm_PrintLn(@"Deleting relationship assertion between %@ and %@...", _myId, [parent valueForKey:@"id"]);
                    [self.service.operationQueue addOperation:oper];
                }
            }
        }
    }
    [self.service.operationQueue waitUntilAllOperationsAreFinished];
}

- (void)killAssertion:(NSDictionary*)assertion ofType:(NSString*)assertionType fromRecord:(NSString*)fromId toRecord:(NSString*)toId
{
//    __block NSDictionary* dict = nil;
//    
//    FSURLOperation* _oper =
//    [self.service familyTreeOperationRelationshipOfReadType:NDFamilyTreeReadType.person
//                                                  forPerson:fromId
//                                           relationshipType:NDFamilyTreeRelationshipType.parent
//                                                  toPersons:[NSArray arrayWithObject:toId]
//                                             withParameters:[NSDictionary dictionaryWithObjectsAndKeys:NDFamilyTreeReadRequestParameter.all, NDFamilyTreeReadPersonsRequestParameter.characteristics, NDFamilyTreeReadRequestParameter.all, NDFamilyTreeReadPersonsRequestParameter.assertions, NDFamilyTreeReadRequestParameter.all, NDFamilyTreeReadPersonsRequestParameter.values, nil]
//                                                  onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
//                                                      dict = response;
//                                                  }
//                                                  onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
//                                                      dm_PrintURLOperationResponse(resp, payload, error);
//                                                  }];
//    [self.service.operationQueue addOperation:_oper];
//    [self.service.operationQueue waitUntilAllOperationsAreFinished];
//    
//    NSDictionary* d = [[dict valueForKeyPath:@"persons"] firstObject];
//    
//    for (NSDictionary* _i in resp) {
//        id parents = [_i valueForKeyPath:@"relationships.parent"];
//        for (NSDictionary* parent in parents) {
//            for (NSString* assertionType in [[parent valueForKey:@"assertions"] allKeys]) {
//                for (NSDictionary* assertion in [[parent valueForKey:@"assertions"] objectForKey:assertionType]) {
//                    FSURLOperation* oper = // note that this may fail horribly for multiple assertions if the deletion causes a version bump.
//                    [self.service familyTreeOperationRelationshipDeleteFromPerson:_myId relationshipType:NDFamilyTreeRelationshipType.parent toPerson:[parent valueForKey:@"id"] relationshipVersion:[parent valueForKey:@"version"] assertionType:assertionType assertion:assertion onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
//                        dm_PrintLn(@"Deleted relationship assertion between %@ and %@", _myId, [parent valueForKey:@"id"]);
//                    } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
//                        dm_PrintURLOperationResponse(resp, payload, error);
//                    }];
//                    dm_PrintLn(@"Deleting relationship assertion between %@ and %@...", _myId, [parent valueForKey:@"id"]);
//                    [self.service.operationQueue addOperation:oper];
//                }
//            }
//        }
//    }
//    [self.service.operationQueue waitUntilAllOperationsAreFinished];
}

@end
