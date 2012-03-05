//
//  DMNFSDeploy55FamilyOperation.h
//  fs-dataman
//
//  Created by Christopher Miller on 3/2/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FSGEDCOMIndividual;
@class NDService;

@interface DMNFSDeploy55FamilyOperation : NSOperation

@property (readwrite, retain) FSGEDCOMIndividual * individual;
@property (readwrite, weak) NDService * service;
@property (readwrite, copy) void(^callback)();

+ (id)individualOperationWithIndividual:(FSGEDCOMIndividual *)individual service:(NDService *)service callback:(void(^)())callback;
- (id)initWithIndividual:(FSGEDCOMIndividual *)individual service:(NDService *)service callback:(void(^)())callback;

@end
