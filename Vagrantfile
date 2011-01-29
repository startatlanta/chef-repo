# Before running vagrant, export the shell variable for the organization on the platform and make sure
# the validator certificate is in ~/.chef.
#
# export ORGNAME=your_platform_organization
#
# Also be sure to export the shell variable for the vagrant box (linux flavor) you will be using
#
# export VAGRANT_BOX=ubuntu10.04-gems
#
# You can optionally export a shell variable for your Chef server username if it is different from your OS user
# export OPSCODE_USER=bofh

user = ENV['OPSCODE_USER'] || ENV['USER']
base_box = ENV['VAGRANT_BOX'] || 'ubuntu10.04-gems'

Vagrant::Config.run do |config|
  config.vm.box = base_box
 
  config.vm.provision :chef_server do |chef|
     
    # Set up some organization specific values based on environment variable above.
    chef.chef_server_url = "https://api.opscode.com/organizations/#{ENV['ORGNAME']}"
    chef.validation_key_path = "#{ENV['HOME']}/.chef/#{ENV['ORGNAME']}-validator.pem"
    chef.validation_client_name = "#{ENV['ORGNAME']}-validator"
 
    # Change the node/client name for the Chef Server
    chef.node_name = "#{user}-vagrant"
 
    # Put the client.rb in /etc/chef so chef-client can be run w/o specifying
    chef.provisioning_path = "/etc/chef"
 
    # logging
    chef.log_level = :info
 
    # adjust the run list to suit your testing needs
    chef.run_list = [
      "role[staging]",
      "role[base]",
      "role[database_master]",
      "role[app]",
      "role[run_migrations]",
      "role[load_balancer]"
    ]
  end
end
