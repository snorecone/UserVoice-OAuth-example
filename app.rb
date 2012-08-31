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
      client.login_verified_user(params[:oauth_verifier])
      redirect to('/')
    end

    if client.logged_in?
      @current_user = JSON.parse(client.get('/api/v1/users/current.json').body)['user']
    end
  end
  
  get '/' do    
    @request_token = client.request_token
    @access_token = client.access_token
    erb :index
  end

  get '/authorize-uservoice' do
    redirect client.authorize_url
  end
    
  run! if app_file == $0
end

