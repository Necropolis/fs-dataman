# FamilySearch Reference Cluster Data Manager

Manage information in FamilySearch's reference cluster like it's Ruby on Rails test fixtures, only from a GEDCOM instead of a bazillion YAML files!

> Note that this is currently not finished, and represents a whole bunch of unfulfilled promises. If you want to help out, please do so. If it doesn't work for you, well, *tough*. You really should have read the non-indemnification bits of the license first.

# Requirements

- Apple Mac OS X 10.7 "Lion"
- Apple LLVM 3.0
- Apple Xcode 4.2 or better
- FamilySearch developer credentials, including API key
- Ruby and the `rake` gem
- At least some command-line -fu

This is completely untested with other Apple Foundation-like environments, sorry!

# What will it do?

The goal and objective of `fs-dataman` is to provide a simple command-line tool for managing the data inside of FamilySearch's FamilyTree Reference Cluster (for developer use only). The basic parts of the tool are:

For actually accurate documentation, read the manpage: (yes, I wrote one).

    git clone git@github.com:NSError/fs-dataman.git
    man ./fs-dataman/fs-dataman/fs-dataman.1
    # get done reading
    rm -rf fs-dataman

For everything else, there's the readme:

## Inspect

    fs-dataman inspect [-l --link] object-id-output-file

Traverse the tree connected to the current user's record and generate an Object ID file for all the connected objects. If you start with data not managed by `fs-dataman`, this is a great way to grab everything so you can start managing it with `fs-dataman`.

With the option of the `-l` flag, you can get just the parents of the current user. This output file is used for the `link` and `unlink` commands.

## Deploy

    fs-dataman deploy [-s --soft] gedcom-file object-id-file

Deploys data to the cluster from the supplied GEDCOM file. The object IDs are deposited into a file. Keep this file! Using it you can easily wipe only the data that came from this GEDCOM.

## Capture

    fs-dataman capture gedcom-file

Capture all the data currently visible (via tree-walking) in the cluster to a GEDCOM file.

## Link

    fs-dataman link object-id-input-file

Link the two (and only two) IDs from the given file to the current user. The two object IDs will be the users parents.

## Unlink

    fs-dataman unlink object-id-output-file

Unlink the two (and only two) IDs from the given file from the current user. The two object IDs will no longer be the user's parents. (Yes, disown them!)

## Nuke

    fs-dataman nuke [-s --soft] [-f --force] object-id-input-file object-id-output-file

Nuke all the data from the cluster that corresponds to the supplied object ID file. Another object ID file is generated - this is all the object IDs that `fs-dataman` failed to destroy. You will need these if you want to complete the destroy, perhaps by running with the `-f` flag. The `--force` flag will instruct `fs-dataman` to run through the whole darn tree and delete everything recursively instead of only just what's specified in the object ID input file.

# I'm interested, how do I set it up?

I've actually made a little Rakefile to get you going. Assuming you have Xcode 4.2 or better and Ruby with the `rake` gem installed, just fire up `Terminal.app` and the following shall get you started:

    # I would suggest you cd into a nice directory here
    git clone git@github.com:NSError/fs-dataman.git
    cd fs-dataman
    rake setup
    rake build
    rake install
    # if you hate this and want to obliterate all two files it installed:
    # rake uninstall

If you don't have Ruby Make (Rake), then here's how:

    # using RVM - you know who you are!
    gem install rake
    # not using RVM
    sudo gem install rake

And then the first code sample should work for you. If you, for some reason, are incapable of running Rake, then read the freaking Rakefile and run the commands by hand. (It's not hard).