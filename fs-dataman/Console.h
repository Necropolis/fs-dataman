//
//  Console.h
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 FSDEV. All rights reserved.
//

#import <Foundation/Foundation.h>

void dm_Print  (NSString* format, ...) NS_FORMAT_FUNCTION(1,2);
void dm_PrintLn(NSString* format, ...) NS_FORMAT_FUNCTION(1,2);

void dm_PrintURLOperationResponse(NSHTTPURLResponse* resp, NSData* payload, NSError* error);
