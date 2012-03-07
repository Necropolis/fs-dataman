//
//  DMNuke.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMNFSNuke.h"

#import "Console.h"
#import "FSArgumentSignature.h"

#import "NDService.h"
#import "NDService+FamilyTree.h"

#import "NSArray+Chunky.h"

#import "FSURLOperation.h"

@implementation DMNFSNuke {
    NSString* _ifile;
    NSString* _ofile;
}

@synthesize outputFile=_outputFile;
@synthesize flag=_flag;
@synthesize inputData=_inputData;

+ (void)load
{
// UNCOMMENT WHEN THE COMMAND IS COMPLETE
    @autoreleasepool {
        [[DMVerb registeredCommands] addObject:[self class]];
    }
}

+ (NSString*)verbCommand
{
    return @"nfs-nuke";
}

+ (NSString*)manpage
{
    return @"fs-dataman-nfs-nuke";
}

- (FSArgumentSignature *)softFlag
{
    static FSArgumentSignature * softFlag;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        softFlag = [FSArgumentSignature argumentSignatureAsFlag:@"s" longNames:@"soft" multipleAllowed:NO];
    });
    return softFlag;
}

- (FSArgumentSignature *)forceFlag
{
    static FSArgumentSignature * forceFlag;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        forceFlag = [FSArgumentSignature argumentSignatureAsFlag:@"f" longNames:@"force" multipleAllowed:NO];
    });
    return forceFlag;
}

- (NSArray *)argumentSignatures
{
    return [NSArray arrayWithObjects:
            [self softFlag],
            [self forceFlag],
            nil];
}

- (void)processArgs
{
    self.flag = NONE;
    if ([[self.arguments.flags objectForKey:[self forceFlag]] boolValue])
        self.flag = FORCE;
    if ([[self.arguments.flags objectForKey:[self softFlag]] boolValue])
        self.flag |= SOFT;
    if ([self.arguments.unnamedArguments count]!=2)
        dm_PrintLn(@"Incorrect number of file arguments for command.");
    // check files
    _ifile=[[self.arguments.unnamedArguments objectAtIndex:0] stringByExpandingTildeInPath];
    _ofile=[[self.arguments.unnamedArguments lastObject] stringByExpandingTildeInPath];
    NSFileManager* _mgr=[NSFileManager defaultManager];
    if ([_mgr fileExistsAtPath:_ifile]&&[_mgr isReadableFileAtPath:_ifile]) {
    } else {
        dm_PrintLnThenDie(@"I cannot open the input file for reading. Dude, this is totally not cool. I'm gunna quit now.");
    }
    NSInputStream * s = [NSInputStream inputStreamWithFileAtPath:_ifile];
    if (!s) {
        dm_PrintLnThenDie(@"I cannot open the input file for reading. Dude, this is totally not cool. I'm gunna quit now.");
    }
    NSError * err;
    self.inputData = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:_ifile] options:0 error:&err];
    if (err) {
        dm_PrintLnThenDie(@"Errored out with %@", err);
    }
    
    [_mgr createFileAtPath:_ofile
                  contents:[NSData data]
                attributes:nil];
    self.outputFile = [NSFileHandle fileHandleForWritingAtPath:_ofile];
    if (self.outputFile==nil) {
        dm_PrintLnThenDie(@"I cannot open the output file for writing. Dude, this is totally not cool. I'm gunna quit now.");
    }
    [self.outputFile truncateFileAtOffset:0];
    // all should be well in Zion, right?
}

- (NSString*)description
{
    NSMutableString* desc = [[NSMutableString alloc] init];
    [desc appendString:@"NUKE with modes "];
    if (MODE_NONE(self.flag)) [desc appendString:@"NONE"];
    else {
        if (MODE_SOFT(self.flag)) [desc appendString:@"SOFT"];
        if (MODE_SOFT_AND_FORCE(self.flag)) [desc appendString:@","];
        if (MODE_FORCE(self.flag)) [desc appendString:@"FORCE"];
    }
    [desc appendFormat:@" with ifile: %@ & ofile: %@", _ifile, _ofile];
    return desc;
}

- (void)run
{   // /run/dos/run https://devnet.familysearch.org/docs/api/familytree-v2/guides/deleting-a-person
    __block NSDictionary * properties;
    __block BOOL stop=NO;
    [self.service familyTreePropertiesOnSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
        properties = response;
    } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
        dm_PrintLn(@"Failed to fetch properties!");
        dm_PrintURLOperationResponse(resp, payload, error);
        stop = YES;
    }]; [self.service.operationQueue waitUntilAllOperationsAreFinished]; if (stop) return;
    
    [[[self.inputData valueForKey:@"persons"] fs_chunkifyWithMaxSize:[[properties objectForKey:@"person.max.ids"] integerValue]] enumerateObjectsUsingBlock:^(NSArray * pids, NSUInteger idx, BOOL *stop) {
        [self.service familyTreeReadPersons:pids withParameters:NDFamilyTreeAllPersonReadValues() onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
            [[response valueForKey:@"persons"] enumerateObjectsUsingBlock:^(NSDictionary * person, NSUInteger idx, BOOL *stop) {
                NSMutableDictionary * deleteAllAssertions = [NSMutableDictionary dictionaryWithCapacity:[NDFamilyTreeAllAssertionTypes() count]];
                for (NSString * type in NDFamilyTreeAllAssertionTypes()) {
                    NSArray * originalAssertions = [person valueForKeyPath:[NSString stringWithFormat:@"assertions.%@", type]];
                    [deleteAllAssertions setObject:[NSMutableArray arrayWithCapacity:[originalAssertions count]] forKey:type];
                    for (NSDictionary * assertion in originalAssertions) {
                        NSDictionary * deleteAssertion = [NSDictionary dictionaryWithObjectsAndKeys:
                                                          @"Delete", @"action", // is that stringly-typed enough for 'ya, buddy?
                                                          [NSDictionary dictionaryWithObject:[assertion valueForKeyPath:@"value.id"] forKey:@"id"], @"value", nil];
                        [[deleteAllAssertions objectForKey:type] addObject:deleteAssertion];
                    }
                }
                dm_PrintLn(@"%@: %@", [person valueForKey:@"id"], deleteAllAssertions);
                
                // drop this in the queue to be killed
                
            }];
        } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
            dm_PrintLn(@"Oh noes!");
        }];
    }];
    
    [self.service.operationQueue waitUntilAllOperationsAreFinished];
    
    // destroy all relationships
    
    dm_PrintLn(@"%@", properties); // relationship.max.ids

    [[self.inputData valueForKey:@"persons"] enumerateObjectsUsingBlock:^(NSString * pid, NSUInteger idx, BOOL *stop) {
        // read the relationships
        __block NSArray * children;
        
        FSURLOperation * getChildrenOperation = // oh dear, sounds like a Caesarian!
        [self.service familyTreeOperationRelationshipOfReadType:NDFamilyTreeReadType.person forPerson:pid relationshipType:NDFamilyTreeRelationshipType.child toPersons:nil withParameters:nil onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
            children = [[response valueForKeyPath:@"persons.relationships.child.id"] firstObject];
        } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
            if ([resp statusCode]==404) { } // do nothing because nothing was found; it's OK
            else {
                dm_PrintLn(@"oops");
                dm_PrintURLOperationResponse(resp, payload, error);
            }
        }]; [self.service.operationQueue addOperation:getChildrenOperation];
        [getChildrenOperation waitUntilFinished];
        
        [[children fs_chunkifyWithMaxSize:[[properties objectForKey:@"relationship.max.ids"] integerValue]] enumerateObjectsUsingBlock:^(NSArray * chunkyChildren, NSUInteger idx, BOOL *stop) {
            FSURLOperation * oper =
            [self.service familyTreeOperationRelationshipOfReadType:NDFamilyTreeReadType.person forPerson:pid relationshipType:NDFamilyTreeRelationshipType.child toPersons:chunkyChildren withParameters:NDFamilyTreeAllRelationshipReadValues() onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
                dm_PrintLn(@"%@", response);
            } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
                dm_PrintLn(@"oops");
                dm_PrintURLOperationResponse(resp, payload, error);
            }];
            [self.service.operationQueue addOperation:oper];
            [oper waitUntilFinished]; // if you don't do that, you run the risk of trying to write two persons at the same time.
        }];
        
    }];
    
    [self.service.operationQueue waitUntilAllOperationsAreFinished];
}

@end
