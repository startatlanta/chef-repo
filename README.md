Start Atlanta Chef Repository
-----------------------------

TODO: THIS README STILL NEEDS TO BE FLESHED OUT!

The Stacks
----------

== Rails 3 + Mysql

knife ec2 server create 'role[production]' 'role[base]' \
  'role[database_master]' 'role[rails_app]' 'role[run_migrations]' \
  -S start-atlanta -I ~/.ssh/start-atlanta.pem -x ubuntu \
  -G default -i ami-88f504e1-f m1.small
  
== Rails 3 + MongoDB

== CakePHP + Mysql

== CakePHP + MongoDB