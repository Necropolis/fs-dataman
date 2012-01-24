//
//  DMUnlink.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/19/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMUnlink.h"

#import "Console.h"

#import "NSArray+DeepMutableCopy.h"
#import "NSDictionary+DeepMutableCopy.h"

#import "NDService.h"
#import "NDService+FamilyTree.h"
#import "FSURLOperation.h"
#import "NSData+StringValue.h"

@implementation DMUnlink {
    NSString* __ifilelocation;
}

@synthesize objectIdsFile=_objectIdsFile;

+ (void)load
{
    @autoreleasepool {
        [[DMVerb registeredCommands] addObject:[self class]];
    }
}

+ (NSString*)verbCommand
{
    return @"unlink";
}

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
    __block NSDictionary* dict = nil; // events chars exists values ordinances assertions properties dispositions contributors personas notes citations
    
    FSURLOperation* _oper =
    [self.service familyTreeOperationRelationshipOfReadType:NDFamilyTreeReadType.person
                                                  forPerson:_myId
                                           relationshipType:NDFamilyTreeRelationshipType.parent
                                                  toPersons:[ids valueForKey:@"persons"]
                                             withParameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             NDFamilyTreeReadRequestValue.all,  NDFamilyTreeReadRequestParameter.events,
                                                             NDFamilyTreeReadRequestValue.all,  NDFamilyTreeReadRequestParameter.characteristics,
                                                             NDFamilyTreeReadRequestValue.all,  NDFamilyTreeReadRequestParameter.exists,
                                                             NDFamilyTreeReadRequestValue.all,  NDFamilyTreeReadRequestParameter.values,
                                                             NDFamilyTreeReadRequestValue.all,  NDFamilyTreeReadRequestParameter.ordinances,
                                                             NDFamilyTreeReadRequestValue.all,  NDFamilyTreeReadRequestParameter.assertions,
                                                             NDFamilyTreeReadRequestValue.all,  NDFamilyTreeReadRequestParameter.dispositions,
                                                             NDFamilyTreeReadRequestValue.all,  NDFamilyTreeReadRequestParameter.contributors,
//                                                           NDFamilyTreeReadRequestValue.all,  NDFamilyTreeReadRequestParameter.personas,
                                                             NDFamilyTreeReadRequestValue.all,  NDFamilyTreeReadRequestParameter.notes,
                                                             NDFamilyTreeReadRequestValue.all,  NDFamilyTreeReadRequestParameter.citations, nil]
                                                  onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
                                                      dict = response;
                                                  }
                                                  onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
                                                      dm_PrintURLOperationResponse(resp, payload, error);
                                                  }];
    [self.service.operationQueue addOperation:_oper];
    [self.service.operationQueue waitUntilAllOperationsAreFinished];
    
    NSArray* parentIds = [[dict valueForKeyPath:@"persons.relationships.parent.id"] firstObject];
    NSArray* relationshipVersions = [[dict valueForKeyPath:@"persons.relationships.parent.version"] firstObject];
    NSMutableArray* assertions = [[[dict valueForKeyPath:@"persons.relationships.parent.assertions"] firstObject] mutableCopy];
    // mutate the assertions to say action=Delete
    for (NSUInteger i0=0;
         i0 < [assertions count];
         ++i0) {
        [assertions replaceObjectAtIndex:i0 withObject:[[assertions objectAtIndex:i0] mutableCopy]];
        NSMutableDictionary* assertionsContainer = [assertions objectAtIndex:i0];
        for (id assertionType in [assertionsContainer allKeys]) {
            [assertionsContainer setObject:[[assertionsContainer objectForKey:assertionType] mutableCopy] forKey:assertionType];
            NSMutableArray* assertionCollection = [assertionsContainer objectForKey:assertionType];
            for (NSUInteger i1=0;
                 i1 < [assertionCollection count];
                 ++i1) {
                [assertionCollection replaceObjectAtIndex:i1 withObject:[[assertionCollection objectAtIndex:i1] mutableCopy]];
                NSMutableDictionary* __assertion = [assertionCollection objectAtIndex:i1];
                [__assertion setObject:@"Delete" forKey:@"action"];
            }
        }
    }
    
    for (NSUInteger i2=0;
         i2 < [parentIds count];
         ++i2) {
        
        FSURLOperation* oper=
        [self.service familyTreeOperationRelationshipUpdateFromPerson:_myId
                                                     relationshipType:NDFamilyTreeRelationshipType.parent
                                                            toPersons:[NSArray arrayWithObject:[parentIds objectAtIndex:i2]]
                                                 relationshipVersions:[NSArray arrayWithObject:[relationshipVersions objectAtIndex:i2]]
                                                           assertions:[NSArray arrayWithObject:[assertions objectAtIndex:i2]]
                                                            onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
                                                                dm_PrintLn(@"Killed parent %@!", [parentIds objectAtIndex:i2]);
                                                            }
                                                            onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
                                                                dm_PrintURLOperationResponse(resp, payload,     error);
                                                            }];
        [self.service.operationQueue addOperation:oper];

    }
    
    [self.service.operationQueue waitUntilAllOperationsAreFinished];
    
}

@end
