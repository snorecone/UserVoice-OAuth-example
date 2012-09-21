require 'bundler'
Bundler.require

class MyApp < Sinatra::Base
  use Rack::Session::Pool, :expire_after => 2592000
  config = YAML.load_file(File.expand_path('../config.yml', __FILE__))
  client = UserVoice::Client.new(config['subdomain_name'],
                                 config['api_key'],
                                 config['api_secret'],
                                :uservoice_domain => config['uservoice_domain'],
                                :protocol => config['protocol'],
                                :callback => 'http://localhost:4567/')
  
  before do
    if params[:oauth_verifier]
      session[:access_token] = client.login_with_verifier(params[:oauth_verifier])
      redirect to('/')
    end

    if session[:access_token]
      @current_user = session[:access_token].get('/api/v1/users/current.json')['user']
    end
  end
  
  get '/' do    
    begin
      @request_token = client.request_token
      @access_token = session[:access_token]
      @q = params[:q] || '/api/v1/users/current.json'
    rescue Errno::ECONNREFUSED
      @auth_system_down = true
    end
    erb :index
  end

  get '/request' do
    begin
      session[:access_token].request(params[:method], params[:q]).to_json
    rescue Exception => e
      e.backtrace.join("\n")
    end
  end

  get '/authorize-uservoice' do
    redirect client.authorize_url
  end
    
  run! if app_file == $0
end

