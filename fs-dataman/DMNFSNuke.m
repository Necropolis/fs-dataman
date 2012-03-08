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

@interface DMNFSNuke ()

@property (readwrite, strong) NSThread * writeThread;

@property (readwrite, strong) NSMutableSet * personsToDelete; //! person assertions to delete
@property (readwrite, strong) NSMutableSet * personsAlreadyDeleted; //! persons already deleted

@property (readwrite, strong) NSMutableSet * childRelationshipsToInvestigate; //! PIDs to fetch all child relationships from
@property (readwrite, strong) NSMutableDictionary * childRelationshipsToDelete; //! PID (key) to NSMutableArray (value) of relationships from/to that need to be deleted
@property (readwrite, strong) NSMutableDictionary * childRelationshipsAlreadyDeleted; //! PID (key) to NSMutableArray (value) of relationships from/to that have been deleted

@property (readwrite, strong) NSMutableSet * parentRelationshipsToInvestigate; //! PIDs to fetch all parent relationships from
@property (readwrite, strong) NSMutableDictionary * parentRelationshipsToDelete; //! PID (key) to NSMutableArray (value) of relationships from/to that need to be deleted
@property (readwrite, strong) NSMutableDictionary * parentRelationshipsAlreadyDeleted; //! PID (key) to NSMutableArray (value) of relationships from/to that have been deleted

@property (readwrite, strong) NSMutableSet * spouseRelatinoshipsToInvestigate; //! PIDs to fetch all spouse relationships from
@property (readwrite, strong) NSMutableDictionary * spouseRelationshipsToDelete; //! PID (key) to NSMutableArray (value) of relationships from/to that need to be deleted
@property (readwrite, strong) NSMutableDictionary * spouseRelationshipsAlreadyDeleted; //! PID (key) to NSMutableArray (value) of relationships from/to that have been deleted

@property (readwrite, strong) NSDictionary * familyTreeProperties;

- (void)addPersonToDeleteIfNotAlreadyDeleted:(NSString *)pid;
- (BOOL)shouldContinueDeleting;

- (void)deletePersonAssertions:(NSDictionary *)personRecord;

@end

@implementation DMNFSNuke {
    NSString* _ifile;
    NSString* _ofile;
}

@synthesize outputFile=_outputFile;
@synthesize soft=_soft;
@synthesize greedy=_greedy;
@synthesize inputData=_inputData;

@synthesize writeThread=_writeThread;

@synthesize personsToDelete=_personsToDelete;
@synthesize personsAlreadyDeleted=_personsAlreadyDeleted;

@synthesize childRelationshipsToInvestigate=_childRelationshipsToInvestigate;
@synthesize childRelationshipsToDelete=_childRelationshipsToDelete;
@synthesize childRelationshipsAlreadyDeleted=_childRelationshipsAlreadyDeleted;

@synthesize parentRelationshipsToInvestigate=_parentRelationshipsToInvestigate;
@synthesize parentRelationshipsToDelete=_parentRelationshipsToDelete;
@synthesize parentRelationshipsAlreadyDeleted=_parentRelationshipsAlreadyDeleted;

@synthesize spouseRelatinoshipsToInvestigate=_spouseRelatinoshipsToInvestigate;
@synthesize spouseRelationshipsToDelete=_spouseRelationshipsToDelete;
@synthesize spouseRelationshipsAlreadyDeleted=_spouseRelationshipsAlreadyDeleted;

@synthesize familyTreeProperties=_familyTreeProperties;

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

- (FSArgumentSignature *)greedyFlag
{
    static FSArgumentSignature * greedyFlag;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        greedyFlag = [FSArgumentSignature argumentSignatureAsFlag:@"g" longNames:@"greedy" multipleAllowed:NO];
    });
    return greedyFlag;
}

- (NSArray *)argumentSignatures
{
    return [NSArray arrayWithObjects:
            [self softFlag],
            [self greedyFlag],
            nil];
}

- (void)processArgs
{
    self.soft = [self.arguments boolValueOfFlag:[self softFlag]];
    self.greedy = [self.arguments boolValueOfFlag:[self greedyFlag]];
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
    [desc appendString:@"NUKE"];
    if (self.soft) [desc appendString:@" SOFTLY"];
    if (self.greedy&&self.soft) [desc appendString:@" and"];
    if (self.greedy) [desc appendString:@" GREEDILY"];
    [desc appendFormat:@" with ifile: %@ & ofile: %@", _ifile, _ofile];
    return desc;
}

- (void)run
{   // /run/dos/run https://devnet.familysearch.org/docs/api/familytree-v2/guides/deleting-a-person
    self.writeThread = [[NSThread alloc] initWithTarget:[FSURLOperation class] selector:@selector(networkRequestThreadEntryPoint:) object:nil];
    [self.writeThread start];
    
    __block BOOL stopCommand=NO;
    [self.service familyTreePropertiesOnSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
        dm_PrintLn(@"Fetched properties");
        self.familyTreeProperties = response;
    } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
        dm_PrintLn(@"Failed to fetch properties!");
        dm_PrintURLOperationResponse(resp, payload, error);
        stopCommand = YES;
    }]; [self.service.operationQueue waitUntilAllOperationsAreFinished]; if (stopCommand) return;
    
    for (NSString * pid in [self.inputData objectForKey:@"persons"])
        [self addPersonToDeleteIfNotAlreadyDeleted:pid];
    
    [self getMe]; // while we haven't actually deleted myself, we're going to pretend that I have just so we can avoid accidentally doing it.
    [self.personsAlreadyDeleted addObject:[[self.me valueForKeyPath:@"persons.id"] firstObject]];
    
    [[[self.inputData valueForKey:@"persons"] fs_chunkifyWithMaxSize:[[self.familyTreeProperties objectForKey:@"person.max.ids"] integerValue]] enumerateObjectsUsingBlock:^(NSArray * pids, NSUInteger idx, BOOL *stop) {
        [self.service familyTreeReadPersons:pids withParameters:NDFamilyTreeAllPersonReadValues() onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
            dm_PrintLn(@"Fetched all assertions for persons %@", [pids componentsJoinedByString:@", "]);
            [[response valueForKey:@"persons"] enumerateObjectsUsingBlock:^(NSDictionary * person, NSUInteger idx, BOOL *stop) {
                [self deletePersonAssertions:person];
            }];
        } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
            dm_PrintLn(@"Oh noes!");
        }];
    }];
    
    [self.service.operationQueue waitUntilAllOperationsAreFinished];
    
    // destroy all relationships
    
    NSMutableArray * deleteChildrenOperations = [NSMutableArray array];

    [[self.inputData valueForKey:@"persons"] enumerateObjectsUsingBlock:^(NSString * pid, NSUInteger idx, BOOL *stop) {
        // read the relationships
        __block NSArray * children;
        
        FSURLOperation * getChildrenOperation = // oh dear, sounds like a Caesarian!
        [self.service familyTreeOperationRelationshipOfReadType:NDFamilyTreeReadType.person forPerson:pid relationshipType:NDFamilyTreeRelationshipType.child toPersons:nil withParameters:nil onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
            dm_PrintLn(@"Read all children for person %@", pid);
            children = [[response valueForKeyPath:@"persons.relationships.child.id"] firstObject];
        } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
            if ([resp statusCode]==404) {
                dm_PrintLn(@"Person %@ has no children", pid);
            } else {
                dm_PrintLn(@"oops");
                dm_PrintURLOperationResponse(resp, payload, error);
            }
        }]; [self.service.operationQueue addOperation:getChildrenOperation];
        [getChildrenOperation waitUntilFinished];
        
        [[children fs_chunkifyWithMaxSize:[[self.familyTreeProperties objectForKey:@"relationship.max.ids"] integerValue]] enumerateObjectsUsingBlock:^(NSArray * chunkyChildren, NSUInteger idx, BOOL *stop) {
            FSURLOperation * oper = // chunkyChildren, possibly related to child obesity McDonald's style?
            [self.service familyTreeOperationRelationshipOfReadType:NDFamilyTreeReadType.person forPerson:pid relationshipType:NDFamilyTreeRelationshipType.child toPersons:chunkyChildren withParameters:NDFamilyTreeAllRelationshipReadValues() onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
                dm_PrintLn(@"Read all child relationship assertions for parent %@ to children %@", pid, [chunkyChildren componentsJoinedByString:@", "]);
                NSDictionary * person = [[response valueForKey:@"persons"] firstObject];
                [[person valueForKeyPath:@"relationships.child"] enumerateObjectsUsingBlock:^(NSDictionary * childRelationship, NSUInteger idx, BOOL *stop) {
                    NSMutableDictionary * deleteAssertions = [NSMutableDictionary dictionary];
                    [[childRelationship valueForKey:@"assertions"] enumerateKeysAndObjectsUsingBlock:^(NSString * assertionType, NSArray * assertions, BOOL *stop) {
                        NSMutableArray * deleteTheseAssertions = [NSMutableArray array];
                        [assertions enumerateObjectsUsingBlock:^(NSDictionary * assertion, NSUInteger idx, BOOL *stop) {
                            [deleteTheseAssertions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                              @"Delete", @"action",
                                                              [NSDictionary dictionaryWithObject:[assertion valueForKeyPath:@"value.id"] forKey:@"id"], @"value", nil]];
                        }];
                        [deleteAssertions setObject:deleteTheseAssertions forKey:assertionType];
                    }];
                    dm_PrintLn(@"%@", deleteAssertions);
                    [deleteChildrenOperations addObject:[self.service familyTreeOperationRelationshipUpdateFromPerson:[person objectForKey:@"id"] relationshipType:NDFamilyTreeRelationshipType.child toPersons:[NSArray arrayWithObject:[childRelationship objectForKey:@"id"]] relationshipVersions:[NSArray arrayWithObject:[childRelationship objectForKey:@"version"]] assertions:[NSArray arrayWithObject:deleteAssertions] onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
                            
                        } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
                        
                    }]];
                }];
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

- (void)addPersonToDeleteIfNotAlreadyDeleted:(NSString *)pid
{
    if (![self.personsAlreadyDeleted containsObject:pid]) [self.personsToDelete addObject:pid];
    @synchronized (_childRelationshipsAlreadyDeleted) { @synchronized (_childRelationshipsToDelete) {
        if ([_childRelationshipsToDelete objectForKey:pid]==nil&&[_childRelationshipsAlreadyDeleted objectForKey:pid]==nil) {
            [self.childRelationshipsToInvestigate addObject:pid];
        }
    } }
    @synchronized (_parentRelationshipsAlreadyDeleted) { @synchronized (_parentRelationshipsToDelete) {
        if ([_parentRelationshipsToDelete objectForKey:pid]==nil&&[_parentRelationshipsAlreadyDeleted objectForKey:pid]==nil) {
            [self.parentRelationshipsToInvestigate addObject:pid];
        }
    } }
    @synchronized (_spouseRelationshipsAlreadyDeleted) { @synchronized (_spouseRelationshipsToDelete) {
        if ([_spouseRelationshipsToDelete objectForKey:pid]==nil&&[_spouseRelationshipsAlreadyDeleted objectForKey:pid]==nil) {
            [self.spouseRelatinoshipsToInvestigate addObject:pid];
        }
    } }
}

- (BOOL)shouldContinueDeleting
{
    return [self.personsToDelete count] > 0           ||
    [self.childRelationshipsToInvestigate  count] > 0 || [self.childRelationshipsToDelete  count] > 0
                                                      ||
    [self.parentRelationshipsToInvestigate count] > 0 || [self.parentRelationshipsToDelete count] > 0
                                                      ||
    [self.spouseRelatinoshipsToInvestigate count] > 0 || [self.spouseRelationshipsToDelete count] > 0;
}

- (void)deletePersonAssertions:(NSDictionary *)personRecord
{
    NSString * pid = [personRecord objectForKey:@"id"];
    NSMutableDictionary * deleteAllAssertions = [NSMutableDictionary dictionaryWithCapacity:[NDFamilyTreeAllAssertionTypes() count]];
    for (NSString * type in NDFamilyTreeAllAssertionTypes()) {
        NSArray * originalAssertions = [personRecord valueForKeyPath:[NSString stringWithFormat:@"assertions.%@", type]];
        [deleteAllAssertions setObject:[NSMutableArray arrayWithCapacity:[originalAssertions count]] forKey:type];
        for (NSDictionary * assertion in originalAssertions) {
            NSDictionary * deleteAssertion = [NSDictionary dictionaryWithObjectsAndKeys:
                                              @"Delete", @"action", // is that stringly-typed enough for 'ya, buddy?
                                              [NSDictionary dictionaryWithObject:[assertion valueForKeyPath:@"value.id"] forKey:@"id"], @"value", nil];
            [[deleteAllAssertions objectForKey:type] addObject:deleteAssertion];
        }
    }
    // TODO: drop deleteAllAssertions this in the queue to be killed
    if (self.soft) {
        dm_PrintLn(@"[[ SOFT ]] %@ detected an deletion actions created, but not taken.", pid);
    } else {
        FSURLOperation * oper =
        [self.service familytreeOperationPersonUpdate:pid assertions:deleteAllAssertions onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
            dm_PrintLn(@"Deleted all assertions for individual %@", pid);
        } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
            dm_PrintLn(@"Failed to delete all assertions for %@", pid);
            dm_PrintURLOperationResponse(resp, payload, error);
        } withTargetThread:self.writeThread];
        [self.service.operationQueue addOperation:oper];
        [oper waitUntilFinished];
    }
}

- (id)init
{
    self = [super init];
    if (!self) return self;
    
    self.personsToDelete = [[NSMutableSet alloc] init];
    self.personsAlreadyDeleted = [[NSMutableSet alloc] init];
    
    self.childRelationshipsToInvestigate = [[NSMutableSet alloc] init];
    self.childRelationshipsToDelete = [[NSMutableDictionary alloc] init];
    self.childRelationshipsAlreadyDeleted = [[NSMutableDictionary alloc] init];
    
    self.parentRelationshipsToInvestigate = [[NSMutableSet alloc] init];
    self.parentRelationshipsToDelete = [[NSMutableDictionary alloc] init];
    self.parentRelationshipsAlreadyDeleted = [[NSMutableDictionary alloc] init];
    
    self.spouseRelatinoshipsToInvestigate = [[NSMutableSet alloc] init];
    self.spouseRelationshipsToDelete = [[NSMutableDictionary alloc] init];
    self.spouseRelationshipsAlreadyDeleted = [[NSMutableDictionary alloc] init];
    
    return self;
}

@end
