# FamilySearch Reference Cluster Data Manager

Manage information in FamilySearch's reference cluster like a boss!

# Requirements

- Apple Mac OS X 10.7 "Lion"
- FamilySearch developer credentials, including API key
- At least some command-line -fu

This is completely untested with other Apple Foundation-like environments, sorry!

# What will it do?

The goal and objective of `fs-dataman` is to provide a simple command-line tool for managing the data inside of FamilySearch's FamilyTree Reference Cluster (for developer use only). The basic parts of the tool are:

## Inspect

    fs-dataman inspect [-l --link] object-id-output-file

Traverse the tree connected to the current user's record and generate an Object ID file for all the connected objects. If you start with data not managed by `fs-dataman`, this is a great way to grab everything so you can start managing it with `fs-dataman`.

With the option of the `-l` flag, you can get just the parents of the current user. This output file is used for the `link` and `unlink` commands.

## Link

    fs-dataman link input-file

Link the two (and only two) IDs from the given file to the current user. The two object IDs will be the users parents.

## Unlink

    fs-dataman unlink output-file

Unlink the two (and only two) IDs from the given file from the current user. The two object IDs will no longer be the user's parents. (Yes, disown them!)

## Show Person

    fs-dataman show-person me

Just dumps the formatted JSON to the standard output of what a person read on the given record ID looks like. You can use me or self as a shortcut for your current user's record ID.

## Show Relationships

    fs-dataman show-relationships MMMM-MMM parent

Show all parent relationships for the given record ID, including all assertions. You can also use `child` and `spouse` to see all of those folks, too!

# I'm interested, how do I set it up?

This is a pre-release version (before I go for broke and open up the code). Download and extract the program to your Mac's hard drive and run the installer:

    tar -xvvf fs-dataman-0.1.tgz
    cd fs-dataman
    sh INSTALL

`fs-dataman` is installed to your hard disk drive at the following locations:

* `/usr/local/bin/fs-dataman`
* `/usr/local/share/man/man1/fs-dataman.1`

You can use `fs-dataman` normally. Read the manpage (`man fs-dataman`, or go to [the web](http://nserror.me/fs-dataman)) to get an idea of how to use the utility. In "the future" I will release the full code.

# Other Notes

The manpage boldly declares that you should report errors using the Github error tracker. That's a little hard because the project is still private. I suggest that you email me instead using the email address that sent the message to the FSDN list.

# Licensing

Free, totally free. See `LICENSE.md` for the real legal-text, but the important part is that you are totally free to use and modify `fs-dataman` as much as you want with absolutely no requirements.