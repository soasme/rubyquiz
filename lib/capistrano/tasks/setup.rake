namespace :setup do
  desc "Upload thin production yml."
  task :upload_thin_yml do
    on roles(:app) do
      execute "mkdir -p #{shared_path}/config/thin"
      upload! StringIO.new(File.read("config/thin/production.yml")), "#{shared_path}/config/thin/production.yml"
    end
  end
end
