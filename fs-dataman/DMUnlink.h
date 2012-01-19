//
//  DMUnlink.h
//  fs-dataman
//
//  Created by Christopher Miller on 1/19/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import "DMVerb.h"

@interface DMUnlink : DMVerb

@property (readwrite, strong) NSFileHandle* objectIdsFile;

@end
