name "database_master"
description "Database master for the application."
run_list(
  "recipe[database::master]"
)
