# A sample Gemfile
source "https://rubygems.org"

ruby '2.1.0'

group :production, :development do
  gem 'sinatra'
  gem 'sinatra-contrib'
  gem 'mongoid', "~> 3.0.0"
  gem 'mongo_ext'
  gem 'bson_ext'
  gem 'rack_csrf'
  gem 'oauth'
  gem 'haml'
end

group :test do
  gem 'rake'
  gem 'rspec'
  gem 'factory_girl'
  gem 'rack-test', require: 'rack/test'
  gem 'nokogiri'
  gem 'watchr'
end

