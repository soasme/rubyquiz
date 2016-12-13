# config valid only for current version of Capistrano
lock "3.7.0"

set :application, "rubyquiz"
set :repo_url, "git@github.com:soasme/rubyquiz.git"

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/rubyquiz
# set :deploy_to, "/var/www/rubyquiz"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# append :linked_files, "config/database.yml", "config/secrets.yml"
append :linked_files, ".env"

# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system"
append :linked_dirs, "log", "tmp/pids", "data"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

set :thin_config_path, -> { "#{shared_path}/config/thin/#{fetch(:stage)}.yml"  }

after 'deploy:publishing', 'deploy:restart_thin'

