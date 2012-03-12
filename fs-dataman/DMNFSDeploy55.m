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

#import "FSURLOperation.h"

@implementation DMNFSDeploy55 {
    NSString* _ifilelocation;
    NSString* _ofilelocation;
    NSString * _meRecord;
}

@synthesize gedcom=_gedcom;
@synthesize outputFile=_outputFile;

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
    if ([self.arguments.unnamedArguments count]!=3) dm_PrintLnThenDie(@"Improper number of arguments, buddy! I need a GEDOM file and the ID of the record corresponding to me, then an output file!");
    _ifilelocation = [[self.arguments.unnamedArguments objectAtIndex:0] stringByExpandingTildeInPath];
    _meRecord = [self.arguments.unnamedArguments objectAtIndex:1];
    _ofilelocation = [[self.arguments.unnamedArguments lastObject] stringByExpandingTildeInPath];
        
    NSFileManager* _mgr=[NSFileManager defaultManager];
    if ([_mgr fileExistsAtPath:_ifilelocation]&&[_mgr isReadableFileAtPath:_ifilelocation]) {
        self.gedcom = [NSFileHandle fileHandleForReadingAtPath:_ifilelocation];
        NSAssert(_gedcom!=nil,@"Seriously, how can this freaking happen?");
    } else {
        dm_PrintLnThenDie(@"I cannot open the input file for reading. Dude, this is totally not cool. I'm gunna quit now.");
    }
    NSDateFormatter * dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH.mm.ss"];
    
    NSDate * date = [[NSDate alloc] init];
    NSString * formattedDateString = [dateFormatter stringFromDate:date];
    
    _ofilelocation = [NSString stringWithFormat:@"%@ %@.json", _ofilelocation, formattedDateString];
    
    [[NSFileManager defaultManager] createFileAtPath:_ofilelocation
                                            contents:[NSData data]
                                          attributes:nil];
    
    self.outputFile = [NSFileHandle fileHandleForWritingAtPath:_ofilelocation];
    [self.outputFile truncateFileAtOffset:0]; // ensure that the darn thing is empty!
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
    
    if (nil==[parsed_gedcom.individuals objectForKey:_meRecord]) {
        dm_PrintLn(@"I really can't be bothered to try and work with a record which isn't there. Try using ged55-list-individuals to find a working ID");
        return;
    }
    
    [self getMe];
    
    NSMutableDictionary * individualOperations = [[NSMutableDictionary alloc] init];
//    NSMutableArray * relationshipOperations = [[NSMutableArray alloc] init];
    NSMutableDictionary * gedcomToPid = [[NSMutableDictionary alloc] init];
    NSMutableArray * slowRelationshipOperations = [[NSMutableArray alloc] init];
    
    [gedcomToPid setValue:[[self.me valueForKeyPath:@"persons.id"] firstObject] forKey:_meRecord];
    
    NSMutableArray * failedCreations = [[NSMutableArray alloc] init];
    NSMutableArray * createdIndividuals = [[NSMutableArray alloc] init];
    
    [parsed_gedcom.individuals enumerateKeysAndObjectsUsingBlock:^(NSString * key, FSGEDCOMIndividual * individual, BOOL *stop) {
        
        if ([key isEqualToString:_meRecord]) return; // Don't upload me! I'm already there!
        
        // make a new update (create) operation and dump it into operations
        FSURLOperation * oper = nil;
        __block NSData * httpbody = nil;
        oper = [self.service familytreeOperationPersonUpdate:nil assertions:[individual nfs_assertionsDescribingIndividual] onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
            NSString * pid = [[response valueForKeyPath:@"persons.id"] firstObject];
            dm_PrintLn(@"[[ WIN  ]] Created %@ => %@", key, pid);
            // put the new PID into some kind of mapping table
            [gedcomToPid setObject:pid forKey:key];
            [createdIndividuals addObject:pid];
        } onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
            [failedCreations addObject:individual];
            dm_PrintLn(@"[[ FAIL ]] Couldn't add %@", key);
            dm_PrintLn(@"           Response: %@", [NSHTTPURLResponse localizedStringForStatusCode:[resp statusCode]]);
        } withTargetThread:nil];
        
        httpbody = [oper.request HTTPBody];
        
        // add req oper to individualOperations for key
        [individualOperations setObject:oper forKey:key];
    }];
    
    [self.service.operationQueue addOperations:[individualOperations allValues] waitUntilFinished:YES];
    
    [parsed_gedcom.families enumerateKeysAndObjectsUsingBlock:^(id key, FSGEDCOMFamily * family, BOOL *stop) {
        NSString * fatherPid, * motherPid;
        if (family.husband) fatherPid = [gedcomToPid objectForKey:family.husband.value];
        if (family.wife) motherPid = [gedcomToPid objectForKey:family.wife.value];
        [family.children enumerateObjectsUsingBlock:^(FSGEDCOMIndividual * child, NSUInteger idx, BOOL *stop) {
            NSString * myPid;
            myPid = [gedcomToPid objectForKey:child.value];
            if (!myPid&&(!fatherPid||!motherPid)) {
                dm_PrintLn(@"[[ FAIL ]] Attempted to create relationship for (%@:%@) to father:(%@:%@) mother:(%@:%@), but too many PIDs were nil",
                           child.value, myPid, family.husband?family.husband.value:@"null", fatherPid, family.wife?family.wife.value:@"null", motherPid);
                return; // just don't do anything
            }
            
            NSMutableDictionary* assertionsContainer = [NSMutableDictionary dictionaryWithCapacity:2];
            [assertionsContainer setObject:[NSMutableArray arrayWithCapacity:1] forKey:NDFamilyTreeAssertionType.exists];
            
            NSMutableDictionary* lineageAssertion = [NSMutableDictionary dictionaryWithCapacity:2];
            [lineageAssertion setObject:@"Affirming" forKey:@"disposition"];
            NSMutableDictionary* lineageValue = [NSMutableDictionary dictionaryWithCapacity:2];
            [lineageValue setObject:@"Biological" forKey:@"lineage"]; // TODO: detect lineage type from GEDCOM
            [lineageValue setObject:@"Lineage" forKey:@"type"];
            [lineageAssertion setObject:lineageValue forKey:@"value"];
            [assertionsContainer setObject:[NSArray arrayWithObject:lineageAssertion] forKey:NDFamilyTreeAssertionType.characteristics];
            
            NSMutableDictionary* existsAssertion = [NSMutableDictionary dictionaryWithCapacity:2];
            [existsAssertion setObject:@"Affirming" forKey:@"disposition"];
            NSMutableDictionary* existsValue = [NSMutableDictionary dictionaryWithCapacity:1];
            [existsValue setObject:[NSNull null] forKey:@"title"];
            [existsAssertion setObject:existsValue forKey:@"value"];
            [assertionsContainer setObject:[NSArray arrayWithObject:existsAssertion] forKey:NDFamilyTreeAssertionType.exists];
            
            NSMutableArray * a = [[NSMutableArray alloc] init];
            if (fatherPid) [a addObject:fatherPid];
            if (motherPid) [a addObject:motherPid];
            
            [a enumerateObjectsUsingBlock:^(NSString * parentPid, NSUInteger idx, BOOL *stop) {
                FSURLOperation * oper =
                [self.service familyTreeOperationRelationshipUpdateFromPerson:myPid
                                                             relationshipType:NDFamilyTreeRelationshipType.parent
                                                                    toPersons:[NSArray arrayWithObject:parentPid]
                                                         relationshipVersions:[NSArray arrayWithObject:@"1"]
                                                                   assertions:[NSArray arrayWithObject:assertionsContainer]
                                                                    onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
                                                                        dm_PrintLn(@"[[ WIN  ]] %@ is now %@'s parent.", fatherPid, myPid);
                                                                    }
                                                                    onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
                                                                        dm_PrintURLOperationResponse(resp, payload, error);
                                                                    }];
                [slowRelationshipOperations addObject:oper];
            }];
        }];
        if (family.husband && family.wife) {
            // create marriage assertion
            
            /* i'm gunna say this now: I effing hate relationship assertions in nfs.
             persons : [
                {
                    id : <id>,
                    relationships : {
                        spouse : [
                            id : <id>,
                            version : numeric,
                            assertions : {
                                exists : [
                                    {
                                        value : {
                                            title : <null>
                                        }
                                    }
                                ]
                            }
                        ]
                    }
                }
             ]                  
             */
            
            NSMutableDictionary * assertions = [NSMutableDictionary dictionary];
            NSMutableArray * existsAssertions = [NSMutableArray array];
            NSMutableDictionary * existsAssertion = [NSMutableDictionary dictionary];
            NSMutableDictionary * existsValue = [NSMutableDictionary dictionary];
            [existsValue setObject:[NSNull null] forKey:@"title"];
            [existsAssertion setObject:existsValue forKey:@"value"];
            [existsAssertions addObject:existsAssertion];
            [assertions setObject:existsAssertions forKey:@"exists"];
            
            FSURLOperation * oper =
            [self.service familyTreeOperationRelationshipUpdateFromPerson:fatherPid
                                                         relationshipType:NDFamilyTreeRelationshipType.spouse
                                                                toPersons:[NSArray arrayWithObject:motherPid]
                                                     relationshipVersions:[NSArray arrayWithObject:@"1"]
                                                               assertions:[NSArray arrayWithObject:assertions]
                                                                onSuccess:^(NSHTTPURLResponse *resp, id response, NSData *payload) {
                                                                    dm_PrintLn(@"[[ WIN  ]] %@ is now married to %@.", fatherPid, motherPid);
                                                                }
                                                                onFailure:^(NSHTTPURLResponse *resp, NSData *payload, NSError *error) {
                                                                    dm_PrintLn(@"[[ FAIL ]] Cannot bind (%@:%@:%@) to (%@:%@:%@)",
                                                                               family.husband.value, fatherPid, [[[family.husband valueForKeyPath:@"NAME"] objectAtIndex:0] valueForKeyPath:@"value"],
                                                                               family.wife.value, motherPid, [[[family.wife valueForKeyPath:@"NAME"] objectAtIndex:0] valueForKeyPath:@"value"]);
                                                                    dm_PrintURLOperationResponse(resp, payload, error);
                                                                }];
            [slowRelationshipOperations addObject:oper];
        }
    }];
    
    [slowRelationshipOperations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self.service.operationQueue addOperation:obj];
        [obj waitUntilFinished];
    }];
    
    NSError * err;
    [self.outputFile writeData:[NSJSONSerialization dataWithJSONObject:[NSDictionary dictionaryWithObjectsAndKeys:createdIndividuals, @"persons", nil] options:NSJSONWritingPrettyPrinted error:&err]];
    if (err) {
        dm_PrintLnThenDie(@"Failed to write output file!");
    }
}

@end
