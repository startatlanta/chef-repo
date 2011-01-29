Start Atlanta Chef Repository
-----------------------------

TODO: THIS README STILL NEEDS TO BE FLESHED OUT!

Pick your Stack
---------------

* Rails 3 + Mysql
* Rails 3 + MongoDB
* CakePHP + Mysql
* CakePHP + MongoDB

Edit the Application Config Data Bag Item
-----------------------------------------

Use knife to create a data bag for users.
  
  % knife data bag create apps

Edit the existing application config for your chosen deploy stack

  % vim data_bags/apps/rails_mysql.json

Upload your application config to the server:

  % knife data bag from file apps rails_mysql.json

Add a User to the Users Data Bag
--------------------------------

Use knife to create a data bag for users.
  
  % knife data bag create users
  
Create a user.

  % knife data bag users bofh
      {
        "id": "bofh",
        "ssh_keys": "ssh-rsa AAA....yhCw== bofh",
        "groups": "sysadmin",
        "uid": 2001,
        "shell": "\/bin\/bash",
        "comment": "BOFH"
      }

Upload the item to the server

  % knife data bag from file users bofh.json
  
Build a Server(s)
-----------------

* pick your environment: staging or production

Run everything on a single server:

    knife ec2 server create 'role[production]' 'role[base]' \
      'role[database_master]' 'role[app]' 'role[run_migrations]' 'role[load_balancer]' \
      -S start-atlanta -I ~/.ssh/start-atlanta.pem -x ubuntu \
      -G default -i ami-88f504e1 -f m1.small

Have separate database, application and load balancer servers:

    knife ec2 server create 'role[production]' 'role[base]' 'role[database_master]' \
      -S start-atlanta -I ~/.ssh/start-atlanta.pem -x ubuntu \
      -G default -i ami-88f504e1 -f m1.small

    knife ec2 server create 'role[production]' 'role[base]' \
      'role[app]' 'role[run_migrations]' \
      -S start-atlanta -I ~/.ssh/start-atlanta.pem -x ubuntu \
      -G default -i ami-88f504e1 -f m1.small

    knife ec2 server create 'role[production]' 'role[base]' 'role[load_balancer]' \
      -S start-atlanta -I ~/.ssh/start-atlanta.pem -x ubuntu \
      -G default -i ami-88f504e1 -f m1.small

