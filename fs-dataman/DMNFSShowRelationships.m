//
//  DMShowRelationship.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/24/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMNFSShowRelationships.h"

#import "Console.h"

#import "NDService.h"
#import "NDService+FamilyTree.h"
#import "NSData+StringValue.h"

#import "FSURLOperation.h"

@implementation DMNFSShowRelationships {
    NSString* _recordId;
    NSString* _relationshipType;
}

+ (void)load
{
    @autoreleasepool {
        [[DMVerb registeredCommands] addObject:[self class]];
    }
}

+ (NSString*)verbCommand
{
    return @"nfs-show-relationships";
}

+ (NSString*)manpage
{
    return @"fs-dataman-nfs-show-relationships";
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"SHOW-RELATIONSHIPS on %@ of type %@", _recordId, _relationshipType];
}

- (void)processArgs
{
    if ([self.__arguments_raw count] != 2) {
        dm_PrintLnThenDie(@"Insufficient arguments; an ID and a relationship type of [%@] must be chosen.", [NDFamilyTreeAllRelationshipTypes() componentsJoinedByString:@" "]);
    }
    _recordId = [self.__arguments_raw objectAtIndex:0];
    _relationshipType = [self.__arguments_raw objectAtIndex:1];
    
    if (![NDFamilyTreeAllRelationshipTypes() containsObject:_relationshipType]) {
        dm_PrintLnThenDie(@"That's not a recognized relationship type; try one of [%@]", [NDFamilyTreeAllRelationshipTypes() componentsJoinedByString:@" "]);
    }
}
    
- (void)run
{
    __block NSDictionary* _resp=nil;
    FSURLOperation* oper =
    [self.service familyTreeOperationRelationshipOfReadType:NDFamilyTreeReadType.person
                                                  forPerson:_recordId
                                           relationshipType:_relationshipType
                                                  toPersons:nil
                                             withParameters:nil
                                                  onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
                                                      _resp = response;
                                                      /////////////// NOTE:
                                                      // If you print the response now, then what happens is the API omits all assertions no matter what you do.
                                                  } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
                                                      dm_PrintURLOperationResponse(resp, payload, error);
                                                  }];
    [self.service.operationQueue addOperation:oper];
    [self.service.operationQueue waitUntilAllOperationsAreFinished];
    NSMutableDictionary* params = [NDFamilyTreeAllRelationshipReadValues() mutableCopy];
    [params removeObjectForKey:NDFamilyTreeReadRequestParameter.personas];
    NSArray* individuals = [[_resp valueForKeyPath:[NSString stringWithFormat:@"persons.relationships.%@.id", _relationshipType]] firstObject];
    for (NSString* individual in individuals) {
        [self.service familyTreeRelationshipOfReadType:NDFamilyTreeReadType.person
                                             forPerson:_recordId
                                      relationshipType:_relationshipType
                                             toPersons:[NSArray arrayWithObject:individual]
                                        withParameters:params
                                             onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
                                                 NSError* err=nil;
                                                 NSData* d = [NSJSONSerialization dataWithJSONObject:response options:NSJSONWritingPrettyPrinted error:&err];
                                                 if (err) dm_PrintLn(@"Wow, can't re-emit the freakin JSON. That's weird man.");
                                                 dm_PrintLn(@"%@", [d fs_stringValue]);

                                             }
                                             onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
                                                 dm_PrintURLOperationResponse(resp, payload, error);
                                             }];
    }
    [self.service.operationQueue waitUntilAllOperationsAreFinished];
}

@end
