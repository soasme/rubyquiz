namespace :deploy do

  desc "Restart thin process"
  task :restart_thin do
    on roles(:app) do
      execute "lsof -i:5000 -t | xargs -I {} kill -9 {}"
      invoke 'thin:start'
    end
  end

end
