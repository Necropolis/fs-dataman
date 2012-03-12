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

- (void)run
{   // /run/dos/run https://devnet.familysearch.org/docs/api/familytree-v2/guides/deleting-a-person

    _allPersons = [[NSMutableSet alloc] init];
    
    /* BATTLE PLAN:
     
     1. Traverse the entire tree.
       
       If greedy is on, descend all relationship links to find more PIDs. Add these new PIDs to the list of PIDs to delete.
     
     2. Delete all assertions on persons.
     
     3. Delete all parent->child relationships.
     
     4. Delete all spouse relationships.

     Note that 1 can be massively parallelized, but requires some fancy locking to prevent bouncing around the tree in an infinite loop.
     
     Note that 2, 3, and 4 can be massively parallelized, but requires some fancy locking to prevent concurrent modification of the same record.
     
     */
    
    // 1. traverse entire tree
    NSMutableArray * a = [[NSMutableArray alloc] init];
    [[self.inputData valueForKey:@"persons"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSAssert([obj isKindOfClass:[NSString class]], @"This PID isn't a string.");
        DMNFSPersonNode * n = [[DMNFSPersonNode alloc] initWithPID:obj];
        [_allPersons addObject:n];
        [a addObject:[NSBlockOperation blockOperationWithBlock:^{
            if (![n isTraversed])
                [n traverseTreeWithService:self.service globalNodeSet:_allPersons recursive:self.greedy queue:self.service.operationQueue lockOrigin:self];
        }]];
    }];
    [self.service.operationQueue addOperations:a waitUntilFinished:NO];
    [self.service.operationQueue waitUntilAllOperationsAreFinished];
    
    // 2. Delete all person assertions
    [_allPersons enumerateObjectsUsingBlock:^(DMNFSPersonNode * person, BOOL *stop) {
        [self.service.operationQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
            [person tearDownWithService:self.service queue:self.service.operationQueue soft:self.soft];
        }]];
    }];
    [self.service.operationQueue waitUntilAllOperationsAreFinished];
}

@end
