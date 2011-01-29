name "run_migrations"
description "Run db:migrate on demand for application"
override_attributes( 
  :apps => { 
    :app => { 
      :production => { :run_migrations => true } 
    } 
  }
)