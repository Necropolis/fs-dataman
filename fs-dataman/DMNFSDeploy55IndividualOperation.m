//
//  DMNFSDeploy55IndividualOperation.m
//  fs-dataman
//
//  Created by Christopher Miller on 3/2/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMNFSDeploy55IndividualOperation.h"

#import "FSURLOperation.h"

#import "NDService.h"
#import "NDService+FamilyTree.h"

#import "FSGEDCOMIndividual+NewDot.h"

@implementation DMNFSDeploy55IndividualOperation

@synthesize individual=_individual;
@synthesize service=_service;
@synthesize callback=_callback;

+ (id)individualOperationWithIndividual:(FSGEDCOMIndividual *)individual service:(NDService *)service callback:(void(^)())callback
{
    return [[[self class] alloc] initWithIndividual:individual service:service callback:callback];
}

- (id)initWithIndividual:(FSGEDCOMIndividual *)individual service:(NDService *)service callback:(void(^)())callback
{
    self = [super init];
    if (!self) return self;
    
    self.individual = individual;
    self.service = service;
    self.callback = callback;
    
    return self;
}

#pragma mark NSOperation

- (BOOL)isConcurrent
{
    return YES;
}

@end
