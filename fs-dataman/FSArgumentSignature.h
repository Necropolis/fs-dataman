//
//  FSArgumentSignature.h
//  fs-dataman
//
//  Created by Christopher Miller on 2/22/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FSArgumentSignature : NSObject
@property (readwrite, strong) NSArray *             names;// just a list of names it reponds to
@property (readwrite, assign, getter = isFlag) BOOL flag;//if a flag, then it won't try and grab the next arg as a value
@property (readwrite, assign, getter = isRequired) BOOL required;//scream and shout if not found
@property (readwrite, assign, getter = isMultipleAllowed) BOOL multipleAllowed;//allow more than one
+ (id)argumentSignatureWithNames:(NSArray *)names flag:(BOOL)flag required:(BOOL)required multipleAllowed:(BOOL)multipleAllowed;
@end
