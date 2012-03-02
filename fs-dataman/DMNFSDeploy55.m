//
//  DMDeploy.m
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMNFSDeploy55.h"

#import "Console.h"

#import "FSArgumentSignature.h"

#import "FSGEDCOM.h"
#import "FSGEDCOMIndividual.h"
#import "FSGEDCOMIndividual+NewDot.h"

#import "FSGEDCOMFamily.h"

#import "NDService.h"
#import "NDService+FamilyTree.h"

#import "NSData+StringValue.h"

@implementation DMNFSDeploy55 {
    NSString* _ifilelocation;
    NSString * _meRecord;
}

@synthesize gedcom=_gedcom;

+ (void)load
{
// UNCOMMENT WHEN THE COMMAND IS COMPLETE
    @autoreleasepool {
        [[DMVerb registeredCommands] addObject:[self class]];
    }
}

+ (NSString*)verbCommand
{
    return @"nfs-deploy55";
}

+ (NSString*)manpage
{
    return @"fs-dataman-nfs-deploy55";
}

- (void)processArgs
{
    if ([self.arguments.unnamedArguments count]!=2) dm_PrintLnThenDie(@"Improper number of arguments, buddy! I need a GEDOM file and the ID of the record corresponding to me");
    _ifilelocation = [[self.arguments.unnamedArguments objectAtIndex:0] stringByExpandingTildeInPath];
    _meRecord = [self.arguments.unnamedArguments lastObject];
        
    NSFileManager* _mgr=[NSFileManager defaultManager];
    if ([_mgr fileExistsAtPath:_ifilelocation]&&[_mgr isReadableFileAtPath:_ifilelocation]) {
        self.gedcom = [NSFileHandle fileHandleForReadingAtPath:_ifilelocation];
        NSAssert(_gedcom!=nil,@"Seriously, how can this freaking happen?");
    } else {
        dm_PrintLnThenDie(@"I cannot open the input file for reading. Dude, this is totally not cool. I'm gunna quit now.");
    }
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"DEPLOY gedcom: %@ with me ID: %@", _ifilelocation, _meRecord];
}

/**
 * I think the best way to think this through is:
 * 
 * 1) Grab the PID of the me record
 * 2) For every record that isn't me, add to NFS 
 * 3) Run through all relationships and add them to NFS (using the union of PIDS of me record and all the records that just got added).
 */
- (void)run
{
    FSGEDCOM* parsed_gedcom = [[FSGEDCOM alloc] init];
    [parsed_gedcom parse:[self.gedcom readDataToEndOfFile]];
    
    NSMutableDictionary * individualOperations = [[NSMutableDictionary alloc] init];
    
    [parsed_gedcom.individuals enumerateKeysAndObjectsUsingBlock:^(NSString * key, FSGEDCOMIndividual * individual, BOOL *stop) {
        
        if ([key isEqualToString:_meRecord]) return; // Don't upload me! I'm already there!
        
        // make a new update (create) operation and dump it into operations
        NSURLRequest * req=
        [self.service familyTreeRequestPersonUpdate:nil assertions:[individual nfs_assertionsDescribingIndividual]];
        
        dm_PrintLn(@"%@", [[req HTTPBody] fs_stringValue]);
        
        // add req oper to individualOperations for key
        
    }];
    
    [parsed_gedcom.families enumerateKeysAndObjectsUsingBlock:^(NSString * key, FSGEDCOMFamily * family, BOOL *stop) {
        
    }];
    
    if (nil==[parsed_gedcom.individuals objectForKey:_meRecord]) {
        dm_PrintLn(@"I really can't be bothered to try and work with a record which isn't there. Try using ged55-list-individuals to find a working ID");
        return;
    }
    
    dm_PrintLn(@"%@", [[parsed_gedcom.individuals objectForKey:_meRecord] nfs_assertionsDescribingIndividual]);

//    dm_PrintLn(@"results of parsing gedcom: %@", parsed_gedcom);
}

@end
