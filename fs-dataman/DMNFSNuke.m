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

#import "DMNFSPersonNode.h"
#import "DMNFSPersonNode_IndividualAssertionsDeleteWrapperOperation.h"
#import "DMNFSPersonNode_RelationshipAssertionsDeleteWrapperOperation.h"

@implementation DMNFSNuke {
    NSString* _ifile;
    NSString* _ofile;
    
    NSFileHandle * _outputFile;
    BOOL _soft;
    BOOL _greedy;
    id _inputData;
    
    NSMutableSet * _allPersons;
}

@synthesize outputFile=_outputFile;
@synthesize soft=_soft;
@synthesize greedy=_greedy;
@synthesize inputData=_inputData;

+ (void)load
{
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

- (NSArray *)_allUnfinishedOperations_:(NSArray *)operations
{
    return [operations filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSOperation * evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject isReady] && ![evaluatedObject isFinished];
    }]];
}

// bonus points for defines in weird places
#define kIndividualsDeletedKey @"individualsDeleted"
#define kRelationshipsDeletedKey @"relationshipDeleted"
#define kFailedIndividualDeletionsKey @"failedIndividualDeletions"
#define kFailedRelationshipDeletionsKey @"failedRelationshipDeletions"

- (void)run
{   // /run/dos/run https://devnet.familysearch.org/docs/api/familytree-v2/guides/deleting-a-person

    _allPersons = [[NSMutableSet alloc] init];
    
    NSOperationQueue * notificationQueue = [[NSOperationQueue alloc] init];
    
    NSMutableDictionary * commandResults = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                            [NSMutableArray array], kIndividualsDeletedKey,
                                            [NSMutableArray array], kRelationshipsDeletedKey,
                                            [NSMutableArray array], kFailedIndividualDeletionsKey,
                                            [NSMutableArray array], kFailedRelationshipDeletionsKey, nil];
    id individualDeletedObserverToken =
    [[NSNotificationCenter defaultCenter] addObserverForName:kIndividualDeletedNotification object:nil queue:notificationQueue usingBlock:^(NSNotification *note) {
        [[commandResults objectForKey:kIndividualsDeletedKey] addObject:note.userInfo];
    }]; id failedIndividualDeletionsObserverToken =
    [[NSNotificationCenter defaultCenter] addObserverForName:kIndividualDeletionFailureNofication object:nil queue:notificationQueue usingBlock:^(NSNotification *note) {
        [[commandResults objectForKey:kFailedIndividualDeletionsKey] addObject:note.userInfo];
    }]; id relationshipsDeletedObserverToken =
    [[NSNotificationCenter defaultCenter] addObserverForName:kRelationshipDeletedNotification object:nil queue:notificationQueue usingBlock:^(NSNotification *note) {
        [[commandResults objectForKey:kRelationshipsDeletedKey] addObject:note.userInfo];
    }]; id failedRelationshipsDeletionObserverToken =
    [[NSNotificationCenter defaultCenter] addObserverForName:kRelationshipDeletionFailureNotification object:nil queue:notificationQueue usingBlock:^(NSNotification *note) {
        [[commandResults objectForKey:kFailedRelationshipDeletionsKey] addObject:note.userInfo];
    }];
    
    // 1. traverse entire tree
    NSMutableArray * a = [[NSMutableArray alloc] init];
    [[self.inputData valueForKey:@"persons"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSAssert([obj isKindOfClass:[NSString class]], @"This PID isn't a string.");
        DMNFSPersonNode * n = [[DMNFSPersonNode alloc] initWithPID:obj];
        [_allPersons addObject:n];
        [a addObject:[NSBlockOperation blockOperationWithBlock:^{
            if (![n isTraversed])
                [n traverseTreeWithService:self.service globalNodeSet:_allPersons recursive:self.greedy queue:self.service.operationQueue];
        }]];
    }];
    [self.service.operationQueue addOperations:a waitUntilFinished:NO];
    [self.service.operationQueue waitUntilAllOperationsAreFinished];
    
    
    // Ensure that the (un-editable) user record is out of the list
    [self getMe];
    DMNFSPersonNode * meNode = [[DMNFSPersonNode alloc] initWithPID:[[self.me valueForKeyPath:@"persons.id"] firstObject]];
    [_allPersons removeObject:meNode];
    
    // 2. Delete all person assertions
    NSMutableArray * allOperations = [[NSMutableArray alloc] init];
    [_allPersons enumerateObjectsUsingBlock:^(DMNFSPersonNode * person, BOOL *stop) {
        [allOperations addObjectsFromArray:[person tearDownWithService:self.service queue:self.service.operationQueue allOperations:allOperations soft:self.soft]];
    }];
    [self.service.operationQueue addOperations:allOperations waitUntilFinished:YES];
    
    [[NSNotificationCenter defaultCenter] removeObserver:individualDeletedObserverToken];
    [[NSNotificationCenter defaultCenter] removeObserver:failedIndividualDeletionsObserverToken];
    [[NSNotificationCenter defaultCenter] removeObserver:relationshipsDeletedObserverToken];
    [[NSNotificationCenter defaultCenter] removeObserver:failedRelationshipsDeletionObserverToken];
    
    NSError * err;
    NSData * commandResults_data =
    [NSJSONSerialization dataWithJSONObject:commandResults options:NSJSONWritingPrettyPrinted error:&err];
    if (err)
        dm_PrintLn(@"Choked on the home stretch! failed to write out results with error: %@", err);
    else
        [self.outputFile writeData:commandResults_data];
}

@end
