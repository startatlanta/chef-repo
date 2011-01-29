db_info = node.run_state[:db_info]

include_recipe "mysql::server"

grants_path = value_for_platform(
  ["centos", "redhat", "suse", "fedora" ] => {
    "default" => "/etc/mysql_app_grants.sql"
  },
  "default" => "/etc/mysql/app_grants.sql"
)

template "/etc/mysql/app_grants.sql" do
  path grants_path
  source "app_grants.sql.erb"
  cookbook "database"
  owner "root"
  group "root"
  mode "0600"
  action :create
  variables :db_info => db_info
end

execute "mysql-install-application-privileges" do
  command "/usr/bin/mysql -u root #{node[:mysql][:server_root_password].empty? ? '' : '-p' }#{node[:mysql][:server_root_password]} < #{grants_path}"
  action :nothing
  subscribes :run, resources(:template => "/etc/mysql/app_grants.sql"), :immediately
end

Gem.clear_paths
require 'mysql'

search(:apps) do |app|
  (app['database_master_role'] & node.run_list.roles).each do |dbm_role|
    app['databases'].each do |env,db|
      if env =~ /#{node[:app_environment]}/
        root_pw = node["mysql"]["server_root_password"]
        mysql_database "create #{db['database']}" do
          host "localhost"
          username "root"
          password root_pw
          database db['database']
          action [:create_db]
        end
      end
    end
  end
end
