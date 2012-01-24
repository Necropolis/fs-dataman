require 'rake'
require 'ronn'

ronn_config = %s{--manual="FamilySearch Utilities" --organization="Christopher Miller"}

task :setup do
  puts 'Cloning submodules - this could take a little moment'
  `git submodule init`
  `git submodule update`
  `cd vendor/NewDot && git submodule init && git submodule update`
end

task :build do
  puts 'Telling Xcode to build the project'
  `xcodebuild -target fs-dataman -configuration Release clean install`
  puts 'Project built!'
end

task :install do
  puts 'Installing /usr/local/bin/fs-dataman'
  `cp -f /tmp/fs-dataman.dst/usr/local/bin/fs-dataman /usr/local/bin/fs-dataman`
  puts 'Installing /usr/local/share/man/man1/fs-dataman.1'
  `ronn #{ronn_config} < fs-dataman/fs-dataman.1.ronn > /usr/local/share/man/man1/fs-dataman.1`
  puts 'fs-dataman is installed! you can now run fs-dataman or read the fs-dataman(1) manpage!'
end

task :uninstall do
  puts 'Uninstalling /usr/local/bin/fs-dataman'
  `rm /usr/local/bin/fs-dataman`
  puts 'Uninstalling /usr/local/share/man/man1/fs-dataman.1'
  `rm /usr/local/share/man/man1/fs-dataman.1`
end

task :manpage do
  `ronn -S #{ronn_config} fs-dataman/fs-dataman.1.ronn`
end
