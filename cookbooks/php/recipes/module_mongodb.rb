file "mongo_ext_conf" do
  path "/etc/php5/conf.d/mongo.ini"
  owner "root"
  group "root"
  mode "0755"
  content "extension=mongo.so"
  action :nothing
end

execute "pecl install mongo" do
  not_if "pecl list | grep mongo"
  notifies :create, "file[mongo_ext_conf]", :immediately 
end