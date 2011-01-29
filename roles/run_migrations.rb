name "run_migrations"
description "Run db:migrate on demand for application"
override_attributes( 
  :apps => { 
    :rails_app => { 
      :production => { :run_migrations => true } 
    },
    :cakephp_app => {
      :production => { :run_migrations => true } 
    } 
  }
)