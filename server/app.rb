require 'sinatra/base'
require 'rack/csrf'
require 'oauth'

require './server/lingr'
require './server/models/user'
require './server/models/database'

HATENA_API_CONSUMER_KEY    = ENV['HBTL_HATENA_API_CONSUMER_KEY']
HATENA_API_CONSUMER_SECRET = ENV['HBTL_HATENA_API_CONSUMER_SECRET']
SESSION_SECRET             = ENV['HBTL_SESSION_SECRET']
CHECK_SECRET_TOKEN         = ENV['HBTL_CHECK_SECRET_TOKEN']
LINGR_ROOM_ID              = ENV['HBTL_LINGR_ROOM_ID']
LINGR_BOT_ID               = ENV['HBTL_LINGR_BOT_ID']
LINGR_BOT_SECRET           = ENV['HBTL_LINGR_BOT_SECRET']

module RackSetup
  def self.registered(app)
    app.use Rack::Session::Cookie,
      :key => 'HATENA_BOOKMARK_TO_LINGR_SID',
      :secret => SESSION_SECRET,
      :expire_after => 60 * 60 * 24 * 20
    app.use Rack::Csrf, :field => 'csrf_token', :skip => ['POST:/lingr_callback', 'POST:/check']
  end
end

class ServerApp < Sinatra::Base
  register RackSetup unless test?

  @@user_index = 0
  
  def check_login
    @flag_login_ok = ! ( session[:login_ip].nil?() || session[:login_ip] != request.ip )
    if @flag_login_ok
      hatena_user_id = session[:hatena_user_id]
      if User.where(:hatena_user_id => hatena_user_id).count == 0
        @user = User.create(
          :hatena_user_id => hatena_user_id,
        )
      else
        @user = User.where(:hatena_user_id => hatena_user_id).first
      end
      @hatena = {
        "id" => hatena_user_id
      }
    end
  end

  def get_hatena_bookmark_tags
    access_token = OAuth::AccessToken.new(
      @consumer,
      @user.hatena_oauth_token,
      @user.hatena_oauth_token_secret,
    )
    res = access_token.request(:get, 'http://b.hatena.ne.jp/1/my/tags')
    raw_tags = JSON.parse(res.body)["tags"]
    tags = raw_tags.map {|tag|
      {
        :tag => tag["tag"],
        :count => tag["count"]
      }
    }
    @user.update_attributes(
      :hatena_bookmark_tags => tags.to_json
    )
    tags.to_json
  end

  configure :development do
    Bundler.require :development
    register Sinatra::Reloader
  end

  configure :production, :development do
    helpers do

      def csrf_token
        Rack::Csrf.csrf_token(env)
      end

      def csrf_tag
        Rack::Csrf.csrf_tag(env)
      end

      def button_show_with_pjax(show_id, label)
        selected = ( request.path == "/page/#{show_id}" )
        if selected
          haml "%button{'data-show-with-pjax' => '#{show_id}', :class => 'btn btn-primary', :disabled => ''} #{label}"
        else
          haml "%button{'data-show-with-pjax' => '#{show_id}', :class => 'btn btn-primary'} #{label}"
        end
      end

      # button_post_request
      def button_post_request(path, label, data = "", action_ok = "", action_ng = "", class_name = "")
        haml "%button{'data-post-req-target' => '#{path}', 'data-params' => '#{data}', 'data-action-ok' => '#{action_ok}', 'data-action-ng' => '#{action_ng}', :class => 'btn btn-primary #{class_name}'} #{label}"
      end

    end
  end

  before do
    @consumer = OAuth::Consumer.new(
      HATENA_API_CONSUMER_KEY,
      HATENA_API_CONSUMER_SECRET,
      :site => 'https://www.hatena.ne.jp',
      :request_token_path => '/oauth/initiate',
      :authorize_path     => '/oauth/authorize',
      :access_token_path  => '/oauth/token',
    )
  end

  get '/' do
    check_login
    haml :index
  end

  post '/lingr_callback' do
    request.body.rewind
    request.body.read
    ''
  end

  post '/hatena_oauth_login' do
    scheme = ENV['https'] == 'on' ? 'https' : 'http'
    oauth_callback_url = "#{scheme}://#{@env['HTTP_HOST']}/hatena_oauth_callback"
    request_token = @consumer.get_request_token(
      {
        :oauth_callback => oauth_callback_url
      },
      :scope => 'read_public'
    )

    # リクエストトークンを保存
    session[:request_token] = request_token.token
    session[:request_token_secret] = request_token.secret

    redirect request_token.authorize_url
  end

  get '/hatena_oauth_callback' do
    request_token = OAuth::RequestToken.new(
      @consumer,
      session[:request_token],
      session[:request_token_secret],
    )

    oauth_token = request_token.get_access_token(
      {},
      :oauth_verifier => params[:oauth_verifier],
    )

    session[:request_token] = nil
    session[:request_token_secret] = nil

    access_token = OAuth::AccessToken.new(
      @consumer,
      oauth_token.token,
      oauth_token.secret,
    )

    res = access_token.request(:get, 'http://n.hatena.com/applications/my.json')
    if res
      hatena_user_info = JSON.parse(res.body)
      hatena_user_id = hatena_user_info["url_name"]

      session[:hatena_user_id] = hatena_user_id
      session[:login_ip] = request.ip

      # ユーザーが存在しない時は作成する
      if User.where(:hatena_user_id => hatena_user_id).count == 0
        # 初期設定を行う
        @user = User.create(
          :hatena_user_id => hatena_user_id,
          :hatena_bookmark_tags => [],
          :watching_tags => [],
          :watching => true,
        )
      else
        @user = User.where(:hatena_user_id => hatena_user_id).first
      end

      @user.update_attributes(
        :hatena_oauth_token => oauth_token.token,
        :hatena_oauth_token_secret => oauth_token.secret
      )

      get_hatena_bookmark_tags
    end

    redirect '/'
  end

  post '/logout' do
    session.destroy()
  end

  #
  # ログイン必須
  #
  
  # メインメニューを表示する
  get '/page/login_menu' do
    check_login
    if @env["HTTP_X_PJAX"] == "true"
      haml :'page/login_menu', :layout => false
    else
      haml :index
    end
  end

  # はてなブックマーク用の設定画面
  get '/page/user_hatena_bookmark_settings' do
    check_login
    if @env["HTTP_X_PJAX"] == "true"
      haml :'page/user_hatena_bookmark_settings', :layout => false
    else
      haml :index
    end
  end

  # タグ一覧を更新する
  post '/api/update_user_tags' do
    check_login
    if @flag_login_ok
      get_hatena_bookmark_tags
    else
      halt 503
    end
  end

  post '/api/get_user_bookmark_tags' do
    check_login
    if @flag_login_ok
      @user.hatena_bookmark_tags
    else
      halt 503
    end
  end

  post '/api/set_user_watching_tag' do
    check_login
    if @flag_login_ok
      watching_tags = @user.watching_tags
      if ! watching_tags.instance_of?(Array)
        watching_tags = []
      end
      new_tag = @params["tag"]
      if watching_tags.bsearch() {|tag| tag <=> new_tag}.nil?()
        watching_tags.push(@params["tag"]).sort!()
        @user.update_attributes({
          :watching_tags => watching_tags
        })
      else
        halt 503
      end
      "OK"
    else
      halt 503
    end
  end

  post '/api/reset_user_watching_tag' do
    check_login
    if @flag_login_ok
      watching_tags = @user.watching_tags
      if ! watching_tags.instance_of?(Array)
        watching_tags = []
      end
      remove_tag = @params["tag"]
      ind = (0..watching_tags.size).bsearch() {|k|
        watching_tags[k] >= remove_tag
      }
      if ind.nil?()
        halt 503
      else
        watching_tags.delete_at(ind)
        @user.update_attributes({
          :watching_tags => watching_tags
        })
      end
      "OK"
    else
      halt 503
    end
  end

  post '/api/get_user_watching_tags' do
    check_login
    if @flag_login_ok
      @user.watching_tags.to_json.to_s
    else
      halt 503
    end
  end

  post '/api/enable_watching' do
    check_login
    if @flag_login_ok
      @user.update_attributes({
        :watching => true
      })
      "OK"
    else
      halt 503
    end
  end

  post '/api/disable_watching' do
    check_login
    if @flag_login_ok
      @user.update_attributes({
        :watching => false
      })
      "OK"
    else
      halt 503
    end
  end

  #
  # ログイン不要
  #
  get '/page/not_login_menu' do
    if @env["HTTP_X_PJAX"] == "true"
      haml :'page/not_login_menu', :layout => false
    else
      haml :index
    end
  end

  # ブックマークの更新を確認する
  def check_user_update
    users = User.all.to_a.select {|user|
      user.hatena_oauth_token != ""
    }
    @@user_index = @@user_index % users.length
    user = users[@@user_index]

    watching_tags = user.watching_tags

    access_token = OAuth::AccessToken.new(
      @consumer,
      user.hatena_oauth_token,
      user.hatena_oauth_token_secret,
    )

    res = access_token.request(:get, 'http://b.hatena.ne.jp/atom/feed')
    list = Hash.from_xml(res.body)
    entries = list["feed"]["entry"].select {|entry|
      tags = entry["subject"]
      tags.any? {|key_tag|
        ret = nil
        watching_tags.bsearch() {|tag|
          ret = tag if tag == key_tag
          tag >= key_tag
        }
        ! ret.nil?
      }
    }

    if entries.size > 0
      last_check_time = user.last_check_time
      if ( last_check_time.nil? || last_check_time == "" )
        last_check_time = DateTime.parse(entries[0]["issued"].to_s).to_i
      else
        new_last_check_time = last_check_time
        new_entries = entries.select {|entry|
          time = DateTime.parse(entry["issued"].to_s).to_i
          new_last_check_time = [new_last_check_time, time].max
          time > last_check_time
        }

        # ここからlingrにポストする
        if new_entries.length > 0
          lingr = Lingr.new(LINGR_ROOM_ID, LINGR_BOT_ID, LINGR_BOT_SECRET)
          line = "--------------------------------------"
          lingr.say("#{line}\n||\n|| --- はてなブックマーク速報 [#{DateTime.now.strftime("%Y-%m-%d %H:%M")}] ---\n|| #{user.hatena_user_id}さんが#{new_entries.length}件ブクマしました\n||\n#{line}")
          new_entries.each_slice(3).each {|entries|
            lingr.say(entries.map {|entry|
              tags = entry["subject"].map {|tag|
                "#{tag}"
              }.join(', ')
              res = "# 『#{entry['title']}』\n-- url: #{entry['link'][0]['href']}\n"
              res += "-- tags: #{tags}\n" if tags.length > 0
            }.join("#{line}\n") + "#{line}\n")
          }
        end

        last_check_time = new_last_check_time
      end

      user.update_attributes({
        :last_check_time => last_check_time
      })
    end

    @@user_index = ( @@user_index + 1 ) % users.length
  end

  post '/check' do
    halt 403 if CHECK_SECRET_TOKEN.nil? || CHECK_SECRET_TOKEN != params[:token]
    check_user_update
    "OK"
  end

  configure :development do
    get '/check' do
      check_user_update
      "OK"
    end

    get '/test_lingr' do
      lingr = Lingr.new(LINGR_ROOM_ID, LINGR_BOT_ID, LINGR_BOT_SECRET)
      lingr.say("hello")
      'OK'
    end
  end
end

