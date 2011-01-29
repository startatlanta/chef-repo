#
# Author:: Joshua Timberman (<joshua@opscode.com>)
# Cookbook Name:: database
# Recipe:: master
#
# Copyright 2009-2010, Opscode, Inc.
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
# This is potentially destructive to the nodes mysql password attributes, since
# we iterate over all the app databags. If this database server provides
# databases for multiple applications, the last app found in the databags
# will win out, so make sure the databags have the same passwords set for
# the root, repl, and debian-sys-maint users.
#

db_info = Hash.new
root_pw = String.new
db_flavor = String.new

search(:apps) do |app|
  (app['database_master_role'] & node.run_list.roles).each do |dbm_role|
    # set the flavor based on the db adapter attribute
    db_flavor = case app["databases"][node.app_environment]["adapter"]
      when /mysql/ then 'mysql'
      when /mong/ then 'mongodb'
    end
    if db_flavor.eql?('mysql')
      %w{ root repl debian }.each do |user|
        user_pw = app["#{db_flavor}_#{user}_password"]
        if !user_pw.nil? and user_pw[node.app_environment]
          Chef::Log.debug("Saving password for #{user} as node attribute node[:#{db_flavor}][:server_#{user}_password")
          node.set[db_flavor]["server_#{user}_password"] = user_pw[node.app_environment]
          node.save
        else
          log "A password for #{db_flavor} user #{user} was not found in DataBag 'apps' item '#{app["id"]}' for environment ' for #{node.app_environment}'." do
            level :warn
          end
          log "A random password will be generated by the #{db_flavor} cookbook and added as 'node.#{db_flavor}.server_#{user}_password'. Edit the DataBag item to ensure it is set correctly on new nodes" do
            level :warn
          end
        end
      end
    end
    app['databases'].each do |env,db|
      db_info[env] = db
    end
  end
end

# pass some data to the next recipe
node.run_state[:db_info] = db_info

include_recipe "database::#{db_flavor}"