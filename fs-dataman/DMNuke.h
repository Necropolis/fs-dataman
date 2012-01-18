//
//  DMNuke.h
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 FSDEV. All rights reserved.
//

#import "DMVerb.h"

@interface DMNuke : DMVerb

@property (readwrite, strong) NSFileHandle* inputFile;
@property (readwrite, strong) NSFileHandle* outputFile;
@property (readwrite, assign) enum flag_t flag;

@end
