require 'rubygems'

class User
  include Mongoid::Document
  field :hatena_user_id
  field :hatena_oauth_token
  field :hatena_oauth_token_secret
  field :hatena_bookmark_tags
  field :watching_tags
  field :watching
  field :last_check_time
end

