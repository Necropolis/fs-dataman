//
//  Deploy.h
//  dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 FSDEV. All rights reserved.
//

#import "DMVerb.h"

@interface DMDeploy : DMVerb

@property (readwrite, strong) NSFileHandle* gedcom;
@property (readwrite, strong) NSFileHandle* outputFile;
@property (readwrite, assign) enum flag_t flag;

@end
