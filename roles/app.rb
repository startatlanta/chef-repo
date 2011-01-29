name "app"
description "front end application server for our app."
run_list(
  "recipe[mysql::client]",
  "recipe[application]"
)
