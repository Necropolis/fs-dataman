//
//  DMVerb.h
//  fs-dataman
//
//  Created by Christopher Miller on 1/13/12.
//  Copyright (c) 2012 Christopher Miller. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NDService;

extern NSString* kConfigServerURL;
extern NSString* kConfigAPIKey;
extern NSString* kConfigUsername;
extern NSString* kConfigPassword;

extern NSString* kConfigSoftShort;
extern NSString* kConfigSoftLong;
extern NSString* kConfigForceShort;
extern NSString* kConfigForceLong;
extern NSString* kConfigLinkShort;
extern NSString* kConfigLinkLong;

enum flag_t {
    NONE=0,
    SOFT=1,
    FORCE=1<<1,
    LINK=1<<2
};

#define MODE_NONE(f)           (0==( f & NONE          ))
#define MODE_SOFT(f)           (0==( f & SOFT          ))
#define MODE_FORCE(f)          (0==( f & FORCE         ))
#define MODE_LINK(f)           (0==( f & LINK          ))
#define MODE_SOFT_AND_FORCE(f) (0==( f & ( SOFT|FORCE )))

/**
 * Describes the basic shared behaviors of all command-line subcommands.
 *
 * All commands are self-registering. Add your command's class to the shared static array obtained from `registeredCommands` at load time, and then the main function will be able to see it and treat it like all the others. For example:
 *
 *     + (void)load
 *     {
 *         [[DMVerb registeredCommands] addObject:[self class]];
 *     }
 *
 * From there you need to provide some basic information about the command, in the form of overriding functions.
 *
 * 1. `verbCommand` is the string that describes what string is mapped to this command. For example, if I had the command `nfs-deploy`, and I wanted `fs-dataman nfs-deploy myfile.ged` to map to that command, I would write `return @"nfs-deploy";` in the `verbCommand` method.
 * 2. `manpage` is the name of the manual page corresponding to this command. You can optionally write a manual page (using Ronn markup) describing this command. It'll allow you to generate spiffy HTML and manpage documentation.
 *
 * Those are all the methods required to just get the command to show up and be mapped. To build a functional command, the following can be overriden:
 *
 * 1. `argumentSignatures` tells the `parseArgs:` method which tokens to look for. Return an array of `FSArgumentSignature` objects; each of these corresponds to either a flag or argument. For more information about that, please see that class's documentation.
 * 2. `shouldLogin` defaults to `YES`. If you return `NO`, then it will not attempt to authenticate with FamilySearch. (This is necessary because the login code fires automatically; you don't need to write out how to log in each and every time).
 * 3. `verbHeader` and `verbFooter` are printed before the command starts and after it finishes.
 * 4. `processArgs` is run before `run`, and is where you should look at the contents of `flags`, `arguments`, and `unnamedArguments` in order to set up any files for read/write, database connections, or any other manner of stuff. If an argument doesn't make sense, you would explode and error the user here.
 * 5. `run` (self explanatory; if you don't get it, consider `NSThread` and get back to me).
 */
@interface DMVerb : NSObject

/** All boolean flags. The presence of the flag indicates that it was found, and the absence of it indicates that it wasn't found. If the flag is found multiple times, you will find multiple identical flags in the array. If a flag has multiple names (eg. `-s` and `--soft`) then there will be an entry for both in the array for each occurrence. Because of this, you only need to look for a single flag signature instead of checking for the presence of both. */
@property (readwrite, strong) NSArray * flags;

/** All arguments, or flags followed by some token that you want to associate with that flag. If an argument is found multiple times, the argument container is replaced with an array instead of a single object. */
@property (readwrite, strong) NSDictionary * arguments;

/** Everything that isn't a flag or an argument is dropped in here as an unnamed argument. This is how you get implicit arguments, for example, in the command `nfs-deploy gedcom.ged`, the file name is the first object in `unnamedArguments`. */
@property (readwrite, strong) NSArray * unnamedArguments;

/** The `NDService` that is set up and logged in for you by the time you hit `run`. */
@property (readwrite, strong) NDService* service;

/** The configuration obtained from the PList. If you have any additional stuff in there, you can get at it from here. */
@property (readwrite, strong) NSDictionary* configuration;

/** The current user's record as obtained by the method `getMe`. */
@property (readwrite, strong) NSDictionary* me;

/**
 * To make a new custom command, add your `DMVerb` subclass to this array at load time (using `+(void)load` override).
 */
+ (NSMutableArray*)registeredCommands;

/**
 * The string representing what this command responds to on the command line.
 */
+ (NSString*)verbCommand;

/**
 * The name of the manpage corresponding to this command.
 */
+ (NSString*)manpage;

/**
 * Internal tool called by main. This populates `flags`, `arguments`, and `unnamedArguments` with their values. Ensure that you override `argumentSignatures` if you want this to be able to identify arguments and flags instead of dumping everything else into `unnamedArguments`.
 */ 
- (void)parseArgs:(NSArray *)immutableArgs;

/**
 * All the argument signatures this command responds to. Everything here will be extracted to a flag or argument, and everything else becomes a value in the `unnamedArguments` array.
 *
 * @seealso FSArgumentSignature
 */
- (NSArray *)argumentSignatures;

/**
 * Return `YES` if this command needs the functionality of logging into FamilySearch; if `NO`, then the login is ignored.
 */
- (BOOL)shouldLogin;

/**
 * Some pretty text to float above the command before it runs. You have full access to all parsed arguments at this point, but no login has been performed.
 */
- (NSString*)verbHeader;

/**
 * Some pretty text to float below the command after it runs. You have full access to the same object, but the session has already been destroyed (the `NDService` has been logged out).
 */
- (NSString*)verbFooter;

/**
 * Method which chains to `processArgs`, prints the `verbHeader`, grabs the global configuration file (or the per-command specified one), then logs in. Don't override this unless you need to do something really funky.
 */
- (void)setUp;

/**
 * Override this method. Here is where you'll want to inspect the argument variables `flags`, `arguments`, and `unnamedArguments`. If one of them is a file name, you'd check for read/write access on that file, etc.
 */
- (void)processArgs;

/**
 * Actually do something. (Overriding this method is suggested).
 */
- (void)run;

/**
 * Clean up the stuff you did. If there were temporary files to delete or something, for instance. Don't forget to call `[super tearDown]` if you override this.
 */
- (void)tearDown;

/**
 * Because obtaining the current record representing "me" is so common, this is a convenience method which will put information regarding that into the ivar `me`.
 */
- (void)getMe;

@end
