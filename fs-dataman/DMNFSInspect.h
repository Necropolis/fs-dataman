//
//  DMInspect.h
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMVerb.h"

@interface DMNFSInspect : DMVerb

@property (readwrite, strong) NSFileHandle* objectIds;
@property (readwrite, assign) enum flag_t flag;

@end
