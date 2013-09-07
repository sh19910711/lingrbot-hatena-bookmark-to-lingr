require 'rubygems'

class Database
  include Mongoid::Document
  field :version
end
