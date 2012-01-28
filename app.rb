require 'bundler'
require 'ostruct'
Bundler.require

module UserVoice
  module OAuth
    class Consumer < ::OAuth::Consumer
      def initialize(opts)      
        subdomain = opts.delete("subdomain")
        key = opts.delete("key")
        secret = opts.delete("secret")
      
        raise unless subdomain && key && secret
      
        site = "https://#{subdomain}.uservoice.com"
        super(key, secret, opts.merge(:site => site))
      end
    end
  end
end

class MyApp < Sinatra::Base
  use Rack::Session::Pool, :expire_after => 2592000
  OauthCallbackUrl = 'http://localhost:4567/'
  UserVoiceConfig = JSON.parse(File.read(File.expand_path("../uservoice_config.json", __FILE__)))
  UserVoiceConsumer = UserVoice::OAuth::Consumer.new(UserVoiceConfig)
  
  before do
    @request_token = session[:request_token]
    @access_token = session[:access_token]
    
    if !@access_token && @request_token && params[:oauth_verifier]
      session[:access_token] = @access_token = @request_token.get_access_token(:oauth_verifier => params[:oauth_verifier])
      @uservoice_user = @access_token.get('/api/v1/users/current.json').body
    elsif @access_token
      @uservoice_user = @access_token.get('/api/v1/users/current.json').body
    end
  end
  
  get '/' do    
    erb :index
  end
  
  get '/authorize-uservoice' do
    request_token = UserVoiceConsumer.get_request_token(:oauth_callback => OauthCallbackUrl)
    session[:request_token] = request_token
    redirect request_token.authorize_url
  end
    
  run! if app_file == $0
end

