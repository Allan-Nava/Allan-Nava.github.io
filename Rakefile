require 'html-proofer'

# rake test
desc "build and test website"

task :test do
  sh "bundle exec jekyll build"
  HTMLProofer.check_directory("./_site",
    url_ignore: [/localhost/],
    only_4xx: true
  ).run
end
