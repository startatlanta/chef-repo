Application cookbook
====================

This cookbook is initially designed to be able to describe and deploy web applications. Currently supported:

* Rails
* Java

Other application stacks (PHP, DJango, etc) will be supported as new recipes at a later date.

This cookbook aims to provide primitives to install/deploy any kind of application driven entirely by data defined in an abstract way through a data bag.

---
Requirements
============

Chef 0.8 or higher required.

The following Opscode cookbooks are dependencies:

* runit
* unicorn
* apache2
* tomcat

The following are also dependencies, though the recipes are considered deprecated, may be useful for future development.

* `ruby_enterprise`
* `passenger_enterprise`

---
Recipes
=======

The application cookbook contains the following recipes.

default
-------

Searches the `apps` data bag and checks that a server role in the app exists on this node, adds the app to the run state and uses the role for the app to locate the recipes that need to be used. The recipes listed in the "type" part of the data bag are included by this recipe, so only the "application" recipe needs to be in the node or role `run_list`.

See below regarding the application data bag structure.

`java_webapp`
-----------

Using the node's `run_state` that contains the current application in the search, this recipe will install required packages, set up the deployment scaffolding, create the context configuration for the servlet container and then performs a `remote_file` deploy.

The servlet container context configuration (`context.xml`) exposes the following JNDI resources which can be referenced by the webapp's deployment descriptor (web.xml):

* A JDBC datasource for all databases in the node's current `app_environment`.  The datasource uses the information (including JDBC driver) specified in the data bag item for the application.
* An Environment entry that matches the node's current `app_environment` attribute value.  This is useful for loading environment specific properties files in the web application. 

This recipe assumes some sort of build process, such as Maven or a Continuous Integration server like Hudson, will create a deployable artifact and make it available for download via HTTP (such as S3).

`passenger_apache2`
-------------------

Requires `apache2` and `passenger_apache2` cookbooks. The `recipe[apache2]` entry should come before `recipe[application]` in the run list.

    "run_list": [
      "recipe[apache2]",
      "recipe[application]"
    ],

Sets up a passenger vhost template for the application using the `apache2` cookbook's `web_app` definition. Use this with the `rails` recipe, in the list of recipes for a specific application type. See data bag example below.

rails
-----

Using the node's `run_state` that contains the current application in the search, this recipe will install required packages and gems, set up the deployment scaffolding, creates database and memcached configurations if required and then performs a revision-based deploy.

This recipe can be used on nodes that are going to run the application, or on nodes that need to have the application code checkout available such as supporting utility nodes or a configured load balancer that needs static assets stored in the application repository.

For Gem Bundler: include `bundler` or `bundler08` in the gems list.  `bundle install` or `gem bundle` will be run before migrations.

For config.gem in environment: `rake gems:install RAILS_ENV=<node environment>` will be run when a Gem Bundler command is not.

In order to manage running database migrations (rake db:migrate), you can use a role that sets the `run_migrations` attribute for the application (`my_app`, below) in the correct environment (production, below). Note the data bag item needs to have migrate set to true. See the data bag example below.

    {
      "name": "my_app_run_migrations",
      "description": "Run db:migrate on demand for my_app",
      "json_class": "Chef::Role",
      "default_attributes": {
      },
      "override_attributes": {
        "apps": {
          "my_app": {
            "production": {
              "run_migrations": true
            }
          }
        }
      },
      "chef_type": "role",
      "run_list": [
      ]
    }

Simply apply this role to the node's run list when it is time to run migrations, and the recipe will remove the role when done.

tomcat
-------

Requires `tomcat` cookbook.

Tomcat is installed, default attributes are set for the node and the app specific context.xml is symlinked over to Tomcat's context directory as the root context (ROOT.xml).

unicorn
-------

Requires `unicorn` cookbook.

Unicorn is installed, default attributes are set for the node and an app specific unicorn config and runit service are created.

---
Deprecated Recipes
==================

The following recipes are deprecated in favor of rails+unicorn, as that is performant enough for many Rails applications, and takes less time to provision new instances. Using these recipes may require additional work to the rest of the stack that wouldn't be required with rails+unicorn because they were early-phase development of this cookbook.

passenger-nginx
---------------

Builds passenger as an nginx module, drops off the configuration file and sets up the site to run the application under nginx with passenger. Does not deploy the code automatically.

`rails_nginx_ree_passenger`
---------------------------

Sets up the application stack with Ruby Enterprise Edition, Nginx and Passenger.

The recipe searches the apps data bag and then installs packages and gems, creates the nginx vhost config and enables the site, sets up the deployment scaffolding, and uses a revision-based deploy for the code. Database and memcached yaml files are written out as well, if required.

---
Application Data Bag (Rail's version)
====================

The applications data bag expects certain values in order to configure parts of the recipe. Below is a paste of the JSON, where the value is a description of the key. Use your own values, as required. Note that this data bag is also used by the `database` cookbook, so it will contain database information as well. Items that may be ambiguous have an example.

The application used in examples is named `my_app` and the environment is `production`. Most top-level keys are Arrays, and each top-level key has an entry that describes what it is for, followed by the example entries. Entries that are hashes themselves will have the description in the value.

Note about "type": the recipes listed in the "type" will be included in the run list via `include_recipe` in the application default recipe based on the type matching one of the `server_roles` values.

Note about `databases`, the data specified will be rendered as the `database.yml` file. In the `database` cookbook, this information is also used to set up privileges for the application user, and create the databases.

Note about gems and packages, the version is optional. If specified, the version will be passed as a parameter to the resource. Otherwise it will use the latest available version per the default `:install` action for the package provider.

    {
      "id": "my_app",
      "server_roles": [
        "application specific role(s), typically the name of the app, e.g., my_app",
        "my_app"
      ],
      "type": {
        "my_app": [
          "recipes in this application cookbook to run for this role",
          "rails",
          "unicorn"
        ]
      },
      "memcached_role": [
        "name of the role used for the app-specific memcached server",
        "my_app_memcached"
      ],
      "database_slave_role": [
        "name of the role used by database slaves, typically named after the app, 'my_app_database_slave'",
        "my_app_database_slave"
      ],
      "database_master_role": [
        "name of the role used by database master, typically named after the app 'my_app_database_master'",
        "my_app_database_master"
      ],
      "repository": "git@github.com:company/my_app.git",
      "revision": {
        "production": "commit hash, branch or tag to deploy"
      },
      "force": {
        "production": "true or false w/o quotes to force deployment, see the rails.rb recipe"
      },
      "migrate": {
        "production": "true or false boolean to force migration, see rails.rb recipe"
      },
      "databases": {
        "production": {
          "reconnect": "true",
          "encoding": "utf8",
          "username": "db_user",
          "adapter": "mysql",
          "password": "awesome_password",
          "database": "db_name_production"
        }
      },
      "mysql_root_password": {
        "production": "password for the root user in mysql"
      },
      "mysql_debian_password": {
        "production": "password for the debian-sys-maint user on ubuntu/debian"
      },
      "mysql_repl_password": {
        "production": "password for the 'repl' user for replication."
      },
      "snapshots_to_keep": {
        "production": "if using EBS, integer of the number of snapshots we're going to keep for this environment."
      },
      "deploy_key": "SSH private key used to deploy from a private git repository",
      "deploy_to": "path to deploy, e.g. /srv/my_app",
      "owner": "owner for the application files when deployed",
      "group": "group for the application files when deployed",
      "packages": {
        "package_name": "specific packages required for installation at the OS level to run the app like libraries and specific version, e.g.",
        "curl": "7.19.5-1ubuntu2"
      },
      "gems": {
        "gem_name": "specific gems required for installation to run the application, and if a specific version is required, e.g.",
        "rails": "2.3.5"
      },
      "memcached": {
        "production": {
          "namespace": "specify the memcache namespace, ie my_app_environment"
        }
      }
    }


---
Application Data Bag (Java webapp version)
====================

The applications data bag expects certain values in order to configure parts of the recipe. Below is a paste of the JSON, where the value is a description of the key. Use your own values, as required. Note that this data bag is also used by the `database` cookbook, so it will contain database information as well. Items that may be ambiguous have an example.

The application used in examples is named `my_app` and the environment is `production`. Most top-level keys are Arrays, and each top-level key has an entry that describes what it is for, followed by the example entries. Entries that are hashes themselves will have the description in the value.

Note about "type": the recipes listed in the "type" will be included in the run list via `include_recipe` in the application default recipe based on the type matching one of the `server_roles` values.

Note about `databases`, the data specified will be rendered as JNDI Datasource `Resources` in the servlet container context confiruation (`context.xml`) file. In the `database` cookbook, this information is also used to set up privileges for the application user, and create the databases.

Note about packages, the version is optional. If specified, the version will be passed as a parameter to the resource. Otherwise it will use the latest available version per the default `:install` action for the package provider.

    {
      "id": "my_app",
      "server_roles": [
        "application specific role(s), typically the name of the app, e.g., my_app",
        "my_app"
      ],
      "type": {
        "my_app": [
          "recipes in this application cookbook to run for this role",
          "java_webapp",
          "tomcat"
        ]
      },
      "database_slave_role": [
        "name of the role used by database slaves, typically named after the app, 'my_app_database_slave'",
        "my_app_database_slave"
      ],
      "database_master_role": [
        "name of the role used by database master, typically named after the app 'my_app_database_master'",
        "my_app_database_master"
      ],
      "wars": {
        "production": {
          "source": "source url of WAR file to deploy",
          "checksum": "SHA256 (or portion thereof) of the WAR file to deploy"
        }
      },
      "databases": {
        "production": {
          "max_active": "100",
          "max_idle": "30",
          "max_wait": "10000",
          "username": "db_user",
          "adapter": "mysql",
          "driver": "com.mysql.jdbc.Driver",
          "port": "3306",
          "password": "awesome_password",
          "database": "db_name_production"
        }
      },
      "mysql_root_password": {
        "production": "password for the root user in mysql"
      },
      "mysql_debian_password": {
        "production": "password for the debian-sys-maint user on ubuntu/debian"
      },
      "mysql_repl_password": {
        "production": "password for the 'repl' user for replication."
      },
      "snapshots_to_keep": {
        "production": "if using EBS, integer of the number of snapshots we're going to keep for this environment."
      },
      "deploy_to": "path to deploy, e.g. /srv/my_app",
      "owner": "owner for the application files when deployed",
      "group": "group for the application files when deployed",
      "packages": {
        "package_name": "specific packages required for installation at the OS level to run the app like libraries and specific version, e.g.",
        "curl": "7.19.5-1ubuntu2"
      }
    }


---
Usage
=====

To use the application cookbook, we recommend creating a role named after the application, e.g. `my_app`. This role should match one of the `server_roles` entries, that will correspond to a `type` entry, in the databag. Create a Ruby DSL role in your chef-repo, or create the role directly with knife.

    % knife role show my_app
    {
      "name": "my_app",
      "chef_type": "role",
      "json_class": "Chef::Role",
      "default_attributes": {
      },
      "description": "",
      "run_list": [
        "recipe[application]"
      ],
      "override_attributes": {
      }
    }

Also recommended is a cookbook named after the application, e.g. `my_app`, for additional application specific setup such as other config files for queues, search engines and other components of your application. The `my_app` recipe can be used in the run list of the role, if it includes the `application` recipe.

You should also have a role for the environment(s) you wish to use this cookbook. Similar to the role above, create the Ruby DSL file in chef-repo, or create with knife directly.

    % knife role show production
    {
      "name": "production",
      "chef_type": "role",
      "json_class": "Chef::Role",
      "default_attributes": {
        "app_environment": "production"
      },
      "description": "production environment role",
      "run_list": [

      ],
      "override_attributes": {
      }
    }

This role uses a default attribute so nodes can be moved into other environments on the fly simply by modifying their node object directly on the Chef Server.

---
License and Author
==================

Author:: Adam Jacob (<adam@opscode.com>)
Author:: Joshua Timberman (<joshua@opscode.com>)
Author:: Seth Chisamore (<schisamo@opscode.com>)

Copyright 2009-2010, Opscode, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
