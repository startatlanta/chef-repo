#
# Cookbook Name:: application
# Recipe:: cake_php
#
# Copyright 2010, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

app = node.run_state[:current_app]

###
# You really most likely don't want to run this recipe from here - let the
# default application recipe work it's mojo for you.
###

packages = value_for_platform([ "centos", "redhat", "fedora", "suse" ] => {"default" => %w(php php-cli php-Smarty)}, "default" => %w{php5 php5-dev php5-cli smarty})

packages.each do |pkg|
  package pkg do
    action :upgrade
  end
end

include_recipe 'php::pear'

node.default[:apps][app['id']][node.app_environment][:run_migrations] = false

## First, install any application specific packages
if app['packages']
  app['packages'].each do |pkg,ver|
    package pkg do
      action :install
      version ver if ver && ver.length > 0
    end
  end
end

directory app['deploy_to'] do
  owner app['owner']
  group app['group']
  mode '0755'
  recursive true
end

directory "#{app['deploy_to']}/shared" do
  owner app['owner']
  group app['group']
  mode '0755'
  recursive true
end

# %w{ log pids system }.each do |dir|
# 
#   directory "#{app['deploy_to']}/shared/#{dir}" do
#     owner app['owner']
#     group app['group']
#     mode '0755'
#     recursive true
#   end
# 
# end

if app.has_key?("deploy_key")
  ruby_block "write_key" do
    block do
      f = ::File.open("#{app['deploy_to']}/id_deploy", "w")
      f.print(app["deploy_key"])
      f.close
    end
    not_if do ::File.exists?("#{app['deploy_to']}/id_deploy"); end
  end

  file "#{app['deploy_to']}/id_deploy" do
    owner app['owner']
    group app['group']
    mode '0600'
  end

  template "#{app['deploy_to']}/deploy-ssh-wrapper" do
    source "deploy-ssh-wrapper.erb"
    owner app['owner']
    group app['group']
    mode "0755"
    variables app.to_hash
  end
end

if app["database_master_role"]
  dbm = nil
  # If we are the database master
  if node.run_list.roles.include?(app["database_master_role"][0])
    dbm = node
  else
  # Find the database master
    results = search(:node, "run_list:role\\[#{app["database_master_role"][0]}\\] AND app_environment:#{node[:app_environment]}", nil, 0, 1)
    rows = results[0]
    if rows.length == 1
      dbm = rows[0]
    end
  end

  # Assuming we have one...
  if dbm
    include_recipe "php::module_#{app['databases'][node[:app_environment]]['adapter']}"
    
    template "#{app['deploy_to']}/shared/database.php" do
      source "database.php.erb"
      owner app["owner"]
      group app["group"]
      mode "644"
      variables(
        :host => dbm['fqdn'],
        :database => app['databases'][node[:app_environment]]
      )
    end
  else
    Chef::Log.warn("No node with role #{app["database_master_role"][0]}, database.php not rendered!")
  end
end

## Then, deploy
deploy_revision app['id'] do
  revision app['revision'][node.app_environment]
  repository app['repository']
  user app['owner']
  group app['group']
  deploy_to app['deploy_to']
  action app['force'][node.app_environment] ? :force_deploy : :deploy
  ssh_wrapper "#{app['deploy_to']}/deploy-ssh-wrapper" if app['deploy_key']
  
  purge_before_symlink([])
  create_dirs_before_symlink([])
  symlinks({})
  symlink_before_migrate({
    "database.php" => "app/config/database.php"
  })
  
  before_migrate do
    if node.app_environment && app['databases'].has_key?(node.app_environment)
      # chef runs before_migrate, then symlink_before_migrate symlinks, then migrations,
      # yet our before_migrate needs database.yml to exist (and must complete before
      # migrations).
      #
      # maybe worth doing run_symlinks_before_migrate before before_migrate callbacks,
      # or an add'l callback.
      execute "(ln -s ../../../shared/database.php app/config/database.php); rm app/config/database.php" do
        ignore_failure true
        cwd release_path
      end
    end
    
    %w{tmp tmp/cache tmp/cache/persistent tmp/cache/models}.each do |dir|
      directory "#{release_path}/app/#{dir}" do
        owner app['owner']
        group app['group']
        mode "0777"
        recursive true
        action :create
      end
    end
  end
  
  if app['migrate'][node.app_environment] && node[:apps][app['id']][node.app_environment][:run_migrations]
    migrate true
    migration_command app['migration_command'] || "cake migration up"
  else
    migrate false
  end
  before_symlink do
    ruby_block "remove_run_migrations" do
      block do
        if node.role?("#{app['id']}_run_migrations")
          Chef::Log.info("Migrations were run, removing role[#{app['id']}_run_migrations]")
          node.run_list.remove("role[#{app['id']}_run_migrations]")
        end
      end
    end
  end
end
