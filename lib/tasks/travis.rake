namespace :travis do
  desc "Create configuration files from examples"
  task :setup do
    puts 'Creating config/database.yml'
    system("cp config/database.yml.travis config/database.yml") and puts "... done"

    puts 'Config/auth.yml'
    system("cp config/auth.yml.example config/auth.yml") and puts "... done"
  end

  desc "Run specs"
  task :ci => ['travis:go_headless', 'db:create', 'db:migrate', :spec, :jshint, 'jasmine:ci']

  task :go_headless do
    require "headless"
  end
end

task :travis => 'travis:ci'
