//
//  DMNuke.h
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMVerb.h"

@interface DMNFSNuke : DMVerb

@property (readwrite, strong) NSFileHandle* outputFile;
@property (readwrite, assign) BOOL soft;
@property (readwrite, assign) BOOL greedy;
@property (readwrite, strong) id inputData;

@end
