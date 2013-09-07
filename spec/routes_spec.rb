# coding: utf-8
require 'spec_helper'
require './server/app'

def get_with_logined_session url
  session = {}
  session[:login_ip_address] = '127.0.0.1'
  session[:login_token] = 'hogepiyo'
  session[:login_user_id] = 'user1'
  get url, {}, 'rack.session' => session
end

def post_with_logined_session(url, obj = {})
  session = {}
  session[:login_ip_address] = '127.0.0.1'
  session[:login_token] = 'hogepiyo'
  session[:login_user_id] = 'user1'
  post url, {}, 'rack.session' => session
end

def get_with_invalid_session url
  session = {}
  session[:login_ip_address] = '127.0.0.1'
  session[:login_token] = 'hogepiyofuga'
  session[:login_user_id] = 'user1'
  get url, {}, 'rack.session' => session
end

def post_with_invalid_session(url, obj = {})
  session = {}
  session[:login_ip_address] = '127.0.0.1'
  session[:login_token] = 'hogepiyofuga'
  session[:login_user_id] = 'user1'
  post url, {}, 'rack.session' => session
end

def post_with_admin_token(url, obj = {})
  obj['token'] = 'admin_token'
  post(url, obj)
end

def post_with_invalid_admin_token(url, obj = {})
  obj['token'] = 'admin_token_invalid'
  post(url, obj)
end



