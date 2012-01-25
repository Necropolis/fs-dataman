//
//  DMShowPerson.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/24/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMShowPerson.h"

#import "Console.h"

#import "NDService.h"
#import "NDService+FamilyTree.h"
#import "NSData+StringValue.h"

@implementation DMShowPerson {
    NSString* _personId;
}

+ (void)load
{
    @autoreleasepool {
        [[DMVerb registeredCommands] addObject:[self class]];
    }
}

+ (NSString*)verbCommand
{
    return @"show-person";
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"SHOW-PERSON %@", _personId?:@"self"];
}

- (void)processArgs
{
    if (1<[self.arguments count]) {
        dm_PrintLnThenDie(@"Improper number of arguments. I only understand how to fetch the information for one record at a time");
    }
    
    NSArray* me_synonyms = [NSArray arrayWithObjects:@"me", @"myself", @"self", nil];
    
    if (1==[self.arguments count]) {
        _personId = [self.arguments objectAtIndex:0];
        if ([me_synonyms containsObject:_personId]) _personId = nil;
        // otherwise treat it like a person id
    } else {
        _personId=nil;
    }
}

- (void)run
{
    NSMutableDictionary* params = [NDFamilyTreeAllPersonReadValues() mutableCopy];
    [params removeObjectForKey:NDFamilyTreeReadRequestParameter.personas];
    [self.service familyTreeReadPersons:nil==_personId?nil:[NSArray arrayWithObject:_personId]
                         withParameters:params
                              onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
                                  NSError* err=nil;
                                  NSData* json = [NSJSONSerialization dataWithJSONObject:response options:NSJSONWritingPrettyPrinted error:&err];
                                  if (err) dm_PrintLn(@"Can't re-emit JSON. Dude, that's freakin weird.");
                                  else dm_PrintLn(@"%@", [json fs_stringValue]);
                              } 
                              onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
                                  dm_PrintURLOperationResponse(resp, payload, error);
                              }];
    [self.service.operationQueue waitUntilAllOperationsAreFinished];
}

@end
