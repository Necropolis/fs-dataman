//
//  DMLink.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/19/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMNFSLink.h"

#import "Console.h"

#import "NDService.h"
#import "NDService+FamilyTree.h"

@implementation DMNFSLink {
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
    return @"nfs-link";
}

+ (NSString*)manpage
{
    return @"fs-dataman-nfs-link";
}

- (void)processArgs
{
    if ([self.unnamedArguments count]!=1) {
        dm_PrintLnThenDie(@"Incorrect number of arguments.");
    }
    
    __ifilelocation = [[self.unnamedArguments objectAtIndex:0] stringByExpandingTildeInPath];
    NSFileManager* _mgr=[NSFileManager defaultManager];
    if ([_mgr fileExistsAtPath:__ifilelocation]&&[_mgr isReadableFileAtPath:__ifilelocation]) {
        self.objectIdsFile = [NSFileHandle fileHandleForReadingAtPath:__ifilelocation];
        NSAssert(_objectIdsFile!=nil,@"Seriously, how can this freaking happen?");
    } else {
        dm_PrintLnThenDie(@"I cannot open the input file for reading. Dude, this is totally not cool. I'm gunna quit now.");
    }
    // all should be well in Zion, right?
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"LINK as parents the ids from file %@ to current the user", __ifilelocation];
}

- (void)run
{
    NSError* err=nil;
    NSDictionary* ids = [NSJSONSerialization JSONObjectWithData:[_objectIdsFile readDataToEndOfFile] options:0 error:&err];
    if (err) {
        dm_PrintLnThenDie(@"Experienced JSON parse error: %@", err);
    }
    
    [self getMe];
    NSString* _myId = [[self.me valueForKeyPath:@"persons.id"] firstObject];
    if (nil==[ids objectForKey:@"persons"]) {
        dm_PrintLnThenDie(@"I cannot work without people, CURRENT_USER. You should know this by now.");
    }
    if (![[ids objectForKey:@"persons"] isKindOfClass:[NSArray class]]) {
        dm_PrintLnThenDie(@"Inconsistency. Something other than an array was where I really wanted for there to be an array.");
    }
    if ([[ids objectForKey:@"persons"] count]!=2) {
        dm_PrintLnThenDie(@"Improper number of people specified. Did you use inspect -l, or just inspect?");
    }
    
    for (NSString* parentId in [ids objectForKey:@"persons"]) {
        // generate a biological relationship with an exists assertion
        NSMutableDictionary* assertionsContainer = [NSMutableDictionary dictionaryWithCapacity:2];
        [assertionsContainer setObject:[NSMutableArray arrayWithCapacity:1] forKey:NDFamilyTreeAssertionType.exists];
        
        NSMutableDictionary* lineageAssertion = [NSMutableDictionary dictionaryWithCapacity:2];
        [lineageAssertion setObject:@"Affirming" forKey:@"disposition"];
        NSMutableDictionary* lineageValue = [NSMutableDictionary dictionaryWithCapacity:2];
        [lineageValue setObject:@"Adoptive" forKey:@"lineage"];
        [lineageValue setObject:@"Lineage" forKey:@"type"];
        [lineageAssertion setObject:lineageValue forKey:@"value"];
        [assertionsContainer setObject:[NSArray arrayWithObject:lineageAssertion] forKey:NDFamilyTreeAssertionType.characteristics];
        
        NSMutableDictionary* existsAssertion = [NSMutableDictionary dictionaryWithCapacity:2];
        [existsAssertion setObject:@"Affirming" forKey:@"disposition"];
        NSMutableDictionary* existsValue = [NSMutableDictionary dictionaryWithCapacity:1];
        [existsValue setObject:[NSNull null] forKey:@"title"];
        [existsAssertion setObject:existsValue forKey:@"value"];
        [assertionsContainer setObject:[NSArray arrayWithObject:existsAssertion] forKey:NDFamilyTreeAssertionType.exists];
        
        [self.service familyTreeRelationshipUpdateFromPerson:_myId
                                            relationshipType:NDFamilyTreeRelationshipType.parent
                                                   toPersons:[NSArray arrayWithObject:parentId]
                                        relationshipVersions:[NSArray arrayWithObject:@"1"]
                                                  assertions:[NSArray arrayWithObject:assertionsContainer]
                                                   onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
                                                       dm_PrintLn(@"%@ is now %@'s parent. Happy adoption!", parentId, _myId);
                                                   }
                                                   onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
                                                       dm_PrintURLOperationResponse(resp, payload, error);
                                                   }];
    }
    
    [self.service.operationQueue waitUntilAllOperationsAreFinished];
}

@end
