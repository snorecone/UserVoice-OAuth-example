require 'bundler'
Bundler.require

class MyApp < Sinatra::Base
  use Rack::Session::Pool, :expire_after => 2592000

  def config
    @config ||= YAML.load_file(File.expand_path('../config.yml', __FILE__))
  end

  def client
    session[:client] ||= UserVoice::Client.new(config['subdomain_name'],
                                 config['api_key'],
                                 config['api_secret'],
                                :uservoice_domain => config['uservoice_domain'],
                                :protocol => config['protocol'],
                                :callback => 'http://localhost:4567/')
  end
  def current_user
    if @current_user.nil? && session[:access_token]
      @current_user = session[:access_token].get('/api/v1/users/current.json')['user']
    end
    return @current_user
  end

  def current_sso_token
    unless current_user.nil?
      user = { :email => current_user['email'], :trusted => true }
      return UserVoice.generate_sso_token(config['subdomain_name'], config['sso_key'], user, 300)
    end
  end
  
  before do
    if params[:oauth_verifier]
      begin
        session[:access_token] = client.login_with_verifier(params[:oauth_verifier])
      rescue UserVoice::Unauthorized
        # false/old verifier
      end
      redirect to('/')
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
    rescue UserVoice::Unauthorized => e
      e.to_s
    end
  end

  get '/logout' do
    session[:access_token] = session[:request_token] = @current_user = nil
    redirect to('/')
  end

  get '/authorize-uservoice' do
    redirect client.authorize_url
  end
    
  run! if app_file == $0
end

