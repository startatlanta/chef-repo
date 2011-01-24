knife ec2 server create 'role[production]' 'role[base]' \
  'role[database_master]' 'role[rails_app_]' 'role[run_migrations]' \
  -S start-atlanta -I ~/.ssh/start-atlanta.pem -x ubuntu \
  -G default -i ami-a403f7cd -f m1.small