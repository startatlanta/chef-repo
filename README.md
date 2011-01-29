Start Atlanta Chef Repository
-----------------------------

This guide describes how to build some pre-configured application stack using Chef cookbooks available from the [Cookbooks Community Site](http://cookbooks.opscode.com) and the Opscode Platform. It assumes you followed the [Getting Started Guide](http://help.opscode.com/faqs/start/how-to-get-started) and have Chef installed.

All stacks have been tested on Ubuntu 10.04 LTS (lucid) in a single server and multi-server arrangement.

* Rails 3 on Unicorn + Mysql
* Rails 3 on Unicorn + MongoDB
* CakePHP on mod_php/Apache2 + Mysql
* CakePHP on mod_php/Apache2 + MongoDB

Environment Setup
-----------------

First, let's configure the local workstation.

### Shell Environment

Obtain the repository used for this guide. It contains all the components required. Use git:

    git clone git://github.com/startatlanta/chef-repo.git

### Chef and Knife

*Ubuntu/Debian users*: Install XML2 and XLST development headers on your system:

    sudo apt-get install libxml2-dev libxslt-dev

*All Users*: You'll need some additional gems for Knife

    sudo gem install fog net-ssh-multi

As part of the [Getting Started Guide](help.opscode.com/faqs/start/how-to-get-started), you downloaded a validation certificate (ORGNAME-validator.pem) and user certificate (USERNAME.pem) to your local workstation.  Create a `.chef` in your user home directory and place the two private key's there.

    mkdir ~/.chef
    cp ~/Downloads/USERNAME.pem ~/.chef/USERNAME.pem
    cp ~/Downloads/ORGNAME-validator.pem ~/.chef/ORGNAME-validator.pem

You will also have to export a few environment variables:
    
    vim ~/.zshrc
    
    #export EDITOR="mate -w"
    export EDITOR="/usr/local/bin/vim" # vim rox
    
    export ORGNAME='replace with your Opscode Platform organization name'
    
    # Amazon AWS
    export AWS_ACCESS_KEY_ID='replace with your Amazon Access Key ID'
    export AWS_SECRET_ACCESS_KEY='replace your the Amazon Secret Access Key ID'
    # Rackspace Cloud
    export RACKSPACE_USERNAME='replace with your Rackspace Username'
    export RACKSPACE_API_KEY='replace with your Rackspace API Key

You can ignore the `knife.rb` file that you downloaded as part of the [Getting Started Guide](help.opscode.com/faqs/start/how-to-get-started), we have included a knife config file along with this chef-repo.  Knife will look for it's configuration file in the current directory first then search upward until it finds a file.  This allows you to have multiple chef repositories all pointed at separate Opscode Platform organizations.

Acquire Cookbooks
----

This chef-repo has all the cookbooks we need for this guide. They were downloaded along with their dependencies from the cookbooks site using Knife. These are in the `cookbooks/` directory.

    apt
    git
    application
    database
    haproxy
    users
    sudo

Upload all the cookbooks to the Opscode Platform.

    knife cookbook upload -a

Server Roles
------------

All the required roles have been created in the rails-quick-start repository. They are in the `roles/` directory.

    base.rb
    production.rb
    staging.rb
    database_master.rb
    app.rb
    run_migrations.rb
    load_balancer.rb

Upload all the roles to the Opscode Platform.

    rake roles

Data Bag Items
--------------

We will be using Chef's Data Bag feature to store data that will be shared between all of the nodes.  The first data bag is called `apps` and contains a data bag item that has all the information required to deploy and configure the application from source using the recipes in the `application` and `database` cookbooks. The other data bag is called `users` and contains an item for each of the users that will be created on our nodes.

### Application Configuration

Edit the example application config for your chosen deploy stack

    vim data_bags/apps/rails_mysql.json

Upload your application config to the server:

    knife data bag from file apps rails_mysql.json

### Users

Create a user item.

    vim data_bags/users/bofh.json
      {
        "id": "bofh",
        "ssh_keys": "ssh-rsa AAA....yhCw== bofh",
        "groups": "sysadmin",
        "uid": 2001,
        "shell": "\/bin\/bash",
        "comment": "BOFH"
      }

Upload the item to the server

    knife data bag from file users bofh.json

Build Your Stack
----------------

* pick your target environment: staging or production

Run everything on a single server:

    knife ec2 server create 'role[production]' 'role[base]' \
      'role[database_master]' 'role[app]' 'role[run_migrations]' 'role[load_balancer]' \
      --ssh-key start-atlanta --identity-file ~/.ssh/start-atlanta.pem --ssh-user ubuntu \
      --groups default --image ami-88f504e1 --flavor m1.small

Have separate database, application and load balancer servers:

    knife ec2 server create 'role[production]' 'role[base]' 'role[database_master]' \
      --ssh-key start-atlanta --identity-file ~/.ssh/start-atlanta.pem --ssh-user ubuntu \
      --groups default --image ami-88f504e1 --flavor m1.small

    knife ec2 server create 'role[production]' 'role[base]' \
      'role[app]' 'role[run_migrations]' \
      --ssh-key start-atlanta --identity-file ~/.ssh/start-atlanta.pem --ssh-user ubuntu \
      --groups default --image ami-88f504e1 --flavor m1.small

    knife ec2 server create 'role[production]' 'role[base]' 'role[load_balancer]' \
      --ssh-key start-atlanta --identity-file ~/.ssh/start-atlanta.pem --ssh-user ubuntu \
      --groups default --image ami-88f504e1 --flavor m1.small

Application Code Deployment
---------------------------

You will not need to use `capistrano` or any other deployment scripts as the `applicaiton` cookbook that is included as part of this chef-repo will automatically "pull" any code updates down from your git repository every time Chef runs on your app server nodes.  You can force a Chef run on your application servers by issue the following Knife command:

    knife ssh 'role:app' 'sudo chef-client' -a ec2.public_hostname --ssh-user ubuntu

Rackspace Cloud Notes
---------------------

The above commands assume you are using Amazon EC2 as your chosen cloud provider.  The `knife ec2 server create` subcommand does provisioning and bootstrapping of your server in a single step.  The current version of the `knife rackspace server create` subcommand require provisioning and bootstrapping to occur in separate steps (this has already been [fixed in Chef HEAD](http://tickets.opscode.com/browse/CHEF-1445)).

To provision a Rackspace Cloud instance use this command:

    knife rackspace server create --server-name startatlanta --flavor 3 --image 49

Image ID 49 is Ubuntu 10.04 LTS (lucid).  Valid flavor IDs are as follows:

    ID 1 = 256 server
    ID 2 = 512 server
    ID 3 = 1GB server
    ID 4 = 2GB server
    ID 5 = 4GB server
    ID 6 = 8GB server
    ID 7 = 15.5GB server

Make note of the public ip address password that is returned by the command above, you will need to to perform the bootstrapping:

    knife bootstrap PUBLIC_IP --run-list 'role[production]','role[base]','role[database_master]','role[app]','role[run_migrations]','role[load_balancer]' \
      --ssh-user root --ssh-password PASSWORD

You can force a Chef run on your application servers by issue the following Knife command:

    knife ssh 'role:app' 'sudo chef-client' -a rackspace.public_hostname --ssh-user USER

Vagrant
-------

Some teams may choose to run a `staging` environment with Vagrant.  We have provided a valid Vagrantfile in this repo that will work correctly with the Opscode Platform.  Please read [Vagrant's Getting Started guide](http://vagrantup.com/docs/getting-started/index.html) to learn more about installing and configuring Vagrant and it's dependancies (VirtualBox).  Using Vagrant will enable you to use your same set of `production` cookbooks, roles and data bags to a fully virtualized environment that runs on your local workstation within VirtualBox.

You will need to install Opscode's `ubuntu10.04-gems` Vagrant box before proceeding.

    vagrant box add ubuntu10.04-gems http://opscode-vagrant-boxes.s3.amazonaws.com/ubuntu10.04-gems.box
    
The `chef.run_list` entry in the Vagrantfile is already configured to build the full stack on a single Vagrant VM running under the `staging` environment.

    vagrant up