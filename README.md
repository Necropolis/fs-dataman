# FamilySearch Reference Cluster Data Manager

Manage information in FamilySearch's reference cluster like a boss!

> Note that this is currently not finished, and represents a whole bunch of unfulfilled promises.

# Requirements

- Apple Mac OS X 10.7 "Lion"
- Apple LLVM 3.0
- Apple Xcode 4.3 or better
- FamilySearch developer credentials, including API key
- Ruby; `rake` and `ronn` gems (`bundler` also helps for getting these)
- At least some command-line -fu

This is completely untested with other Apple Foundation-like environments, sorry!

# What will it do?

The goal and objective of `fs-dataman` is to provide a simple command-line tool for managing the data inside of FamilySearch's FamilyTree Reference Cluster (for developer use only). The basic parts of the tool are:

## Deploy

    fs-dataman nfs-deploy55 gedcom me-id
   
Deploy a bunch of data from a GEDCOM 5.5.1 file to the cluster, using `me-id` as the linked ID of the record in the GEDCOM that represents the record of the current user in the cluster. (this command is probably the coolest thing evar).

## Inspect

    fs-dataman nfs-inspect [-l --link] object-id-output-file

Traverse the tree connected to the current user's record and generate an Object ID file for all the connected objects. If you start with data not managed by `fs-dataman`, this is a great way to grab everything so you can start managing it with `fs-dataman`.

With the option of the `-l` flag, you can get just the parents of the current user. This output file is used for the `link` and `unlink` commands.

## Link

    fs-dataman nfs-link input-file

Link the two (and only two) IDs from the given file to the current user. The two object IDs will be the users parents.

## Unlink

    fs-dataman nfs-unlink output-file

Unlink the two (and only two) IDs from the given file from the current user. The two object IDs will no longer be the user's parents. (Yes, disown them!)

## Show Person

    fs-dataman nfs-show-person me

Just dumps the formatted JSON to the standard output of what a person read on the given record ID looks like. You can use me or self as a shortcut for your current user's record ID.

## Show Relationships

    fs-dataman nfs-show-relationships MMMM-MMM parent

Show all parent relationships for the given record ID, including all assertions. You can also use `child` and `spouse` to see all of those folks, too!

## List Individuals

    fs-dataman ged55-list-individuals gedcom
   
List all the individuals in a GEDCOM file, with their linked ID. This is useful for finding the right ID to plug into `nfs-deploy55` without going bonkers reading the GEDCOM file in a text editor.

# I'm interested, how do I set it up?

I've actually made a little Rakefile to get you going. Assuming you have Xcode 4.3 or better (with the associated command-line tools installed) and Ruby (either 1.9.3 or Rubinius) with the `bundler` gem installed, just fire up `Terminal.app` and the following shall get you started:

    # I would suggest you cd into a nice directory here
    git clone --recursive git@github.com:NSError/fs-dataman.git
    cd fs-dataman
    bundle install
    rake build
    rake install
    # if you hate this and want to obliterate all two files it installed:
    # rake uninstall

If you aren't using it already, I *highly* recommend [RVM](http://beginrescueend.com/), which makes you a total Ruby rockstar without much effort at all.

To see actually up-to-date information about `fs-dataman`, there's also a manpage:

    man fs-dataman # available after install

You can also look at a fancy formatted HTML page at `gh-pages/index.html`. This is the same page that would be pushed up to `http://nserror.me/fs-dataman`.

# Licensing

Free, totally free. See `LICENSE.md` for the real legal-text, but the important part is that you are totally free to use and modify `fs-dataman` as much as you want with absolutely no requirements. I've also made the command stuff documented, so if you want it should be super-easy to write your own commands, as well. The argument parser code is fairly spiffy, too.