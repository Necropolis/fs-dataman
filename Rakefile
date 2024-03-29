require 'bundler/setup'
require 'rake'
require 'rake/clean'
require 'ronn'

ronn_files = FileList['man/*.1.ronn']

DOCWEB='man-html'
GITWEB='gh-pages'

CLEAN=FileList[
  'man-html',
  'gh-pages',
  'build'
]
CLOBBER=FileList[
  '/tmp/fs-dataman.dst'
]

def man_file(ronn_file)
  ronn_file.gsub /\.ronn$/, ''
end

def man_html(ronn_file)
  ronn_file.gsub /\.ronn$/, '.html'
end

ronn_config = %s{--manual="FamilySearch Utilities" --organization="Christopher Miller"}
ronn_style =  %s{--style=man,toc}

desc "Setup the environment, mainly just clone all the submodules"
task :setup do
  puts 'Cloning submodules - this could take a little moment'
  sh "git submodule init"
  sh "git submodule --init --recursive update "
end

desc "Generate manpages & documentation"
task :mangen do
  sh "mkdir -p /tmp/fs-dataman.dst/usr/local/share/man/man1/"
  sh "mkdir -p #{DOCWEB}"
  sh "mkdir -p #{GITWEB}"
  sh "ronn #{ronn_config} #{ronn_style} #{ronn_files.shelljoin}"
  ronn_files.each do |ronn_file|
    sh "mv -f #{man_file(ronn_file)} /tmp/fs-dataman.dst/usr/local/share/man/man1/"
    sh "cp -f #{man_html(ronn_file)} #{DOCWEB}/"
    sh "mv -f #{man_html(ronn_file)} #{GITWEB}/"
  end
  sh "mv #{DOCWEB}/fs-dataman.1.html #{DOCWEB}/index.html"
  sh "mv #{GITWEB}/fs-dataman.1.html #{GITWEB}/index.html"
end

desc "Upload docs to server"
task :docload do
  sh "rsync -vrutzh --chmod=ugo=rw --progress --delete #{DOCWEB}/ fsdev.net:nserror.me/fs-dataman"
end

desc "Setup gh-pages as a copy of remote repo (for publishing docs)"
task :gh_pages_clone do
  sh "git clone git@github.com:NSError/fs-dataman.git #{GITWEB}"
  cd GITWEB do
    sh "git checkout #{GITWEB}"
  end
end

desc "Push generated docs to gh-pages"
task :gh_pages_push do
  cd GITWEB do
    sh "git add ."
    sh "git add -u"
    sh "git commit --allow-empty-message -m ''"
    sh "git push origin gh-pages --force"
  end
end

desc "Build the project and manpages"
task :build => [:mangen] do
  sh "xcodebuild -target fs-dataman -configuration Release clean install"
end

desc "Install built executables to the system"
task :install do
  sh "install /tmp/fs-dataman.dst/usr/local/bin/fs-dataman /usr/local/bin/fs-dataman"
  FileList['/tmp/fs-dataman.dst/usr/local/share/man/man1/*.1'].each do |ronn_file|
    sh "install #{ronn_file} /usr/local/bin/#{ronn_file.pathmap('%f')}"
  end
end

desc "Remove all installed files from the system"
task :uninstall do
  sh "rm /usr/local/bin/fs-dataman"
  ronn_files.each do |ronn_file|
    sh "rm /usr/local/share/man/man1/#{man_file(ronn_file).pathmap('%f')}"
  end
end

desc "Preview manpages using local web server"
task :manpreview do
  sh "ronn -S #{ronn_style} #{ronn_config} fs-dataman/*.1.ronn"
end
