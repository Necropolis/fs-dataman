require 'rake'

task :setup do
  `git submodule init`
  `git submodule update`
  `cd vendor/NewDot && git submodule init && git submodule update`
end

task :build do
  `xcodebuild -target fs-dataman -configuration Release -scheme fs-dataman clean install`
end

task :install do
  `cp /tmp/fs-dataman.dst/usr/local/bin/fs-dataman /usr/local/bin/fs-dataman`
  `cp /tmp/fs-dataman.dst/usr/local/share/man/man1/fs-dataman.1 /usr/local/share/man/man1/fs-dataman.1`
end

task :uninstall do
  `rm /usr/local/bin/fs-dataman`
  `rm /usr/local/share/man/man1/fs-dataman.1`
end
