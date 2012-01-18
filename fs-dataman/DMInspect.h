//
//  DMInspect.h
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 FSDEV. All rights reserved.
//

#import "DMVerb.h"

@interface DMInspect : DMVerb

@property (readwrite, strong) NSFileHandle* objectIds;
@property (readwrite, strong) NSFileHandle* gedcom;

@end
