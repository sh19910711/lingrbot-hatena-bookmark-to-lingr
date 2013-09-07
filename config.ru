require 'bundler'
Bundler.require

require 'mongoid'
Mongoid.load!("mongoid.yml", ENV['RACK_ENV'].to_sym)

require 'rack/csrf'

require './server/app'
run ServerApp
