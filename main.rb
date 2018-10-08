# frozen_string_literal: true

# Copyright (c) 2018 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

STDOUT.sync = true

require 'time'
require 'haml'
require 'redcarpet'
require 'json'
require 'sinatra'
require 'sinatra/cookies'
require 'raven'
require 'omniauth-twitter'
require_relative 'version'
require_relative 'objects/author'

if ENV['RACK_ENV'] != 'test'
  require 'rack/ssl'
  use Rack::SSL
end

configure do
  Haml::Options.defaults[:format] = :xhtml
  config = {
    'twitter' => {
      'api_key' => '',
      'api_secret' => '',
      'access_token' => '',
      'access_secret' => ''
    },
    'pgsql' => {
      'host' => 'localhost',
      'port' => 0,
      'user' => 'test',
      'dbname' => 'test',
      'password' => 'test'
    },
    'sentry' => ''
  }
  config = YAML.safe_load(File.open(File.join(File.dirname(__FILE__), 'config.yml'))) unless ENV['RACK_ENV'] == 'test'
  if ENV['RACK_ENV'] != 'test'
    Raven.configure do |c|
      c.dsn = config['sentry']
      c.release = VERSION
    end
  end
  enable :sessions
  set :dump_errors, false
  set :show_exceptions, false
  set :config, config
  set :logging, true
  set :server_settings, timeout: 25
  set :pgsql, Pgsql.new(
    host: config['pgsql']['host'],
    port: config['pgsql']['port'].to_i,
    dbname: config['pgsql']['dbname'],
    user: config['pgsql']['user'],
    password: config['pgsql']['password']
  )
  use OmniAuth::Builder do
    provider :twitter, config['twitter']['api_key'], config['twitter']['api_secret']
  end
end

before '/*' do
  @locals = {
    ver: VERSION,
    request_ip: request.ip
  }
end

get '/auth/twitter/callback' do
  session[:author] = env['omniauth.auth'][:info][:nickname]
  redirect to('/')
end

get '/auth/failure' do
  params[:message]
end

get '/login' do
  redirect to('/auth/twitter')
end

get '/logout' do
  session.delete(:author)
  redirect to('/')
end

get '/hello' do
  haml :hello, layout: :layout, locals: merged(
    title: '/'
  )
end

get '/' do
  haml :inbox, layout: :layout, locals: merged(
    title: '/',
    inbox: author.inbox
  )
end

get '/create' do
  haml :create, layout: :layout, locals: merged(
    title: '/create'
  )
end

post '/do-create' do
  soalition = author.soalitions.create(params[:name], params[:icon], params[:description])
  flash('/share', "A new soalition ##{soalition.id} has been created")
end

get '/share' do
  haml :share, layout: :layout, locals: merged(
    title: '/share',
    soalitions: author.soalitions
  )
end

post '/do-share' do
  soalition = author.soalitions.one(params[:id])
  soalition.share(current_author, params[:uri])
  flash("/soalition?id=#{soalition.id}", "Your post was shared to the soalition ##{soalition.id}")
end

get '/do-approve' do
  post = author.post(params[:id].to_i)
  post.approve(current_author)
  flash('/', "The post of @#{post.author} has been approved")
end

get '/do-reject' do
  post = author.post(params[:id].to_i)
  post.reject(current_author)
  flash('/', "The post of @#{post.author} has been rejected")
end

get '/repost' do
  post = author.post(params[:id].to_i)
  haml :repost, layout: :layout, locals: merged(
    title: '/repost',
    post: post
  )
end

get '/do-repost' do
  post = author.post(params[:id].to_i)
  post.repost(current_author, params[:uri])
  flash('/', "Your contribution to the post of @#{post.author} has been submitted")
end

get '/soalition' do
  soalition = author.soalitions.one(params[:id])
  haml :soalition, layout: :layout, locals: merged(
    title: "##{soalition.id}",
    soalition: soalition
  )
end

get '/robots.txt' do
  content_type 'text/plain'
  "User-agent: *\nDisallow: /"
end

get '/version' do
  content_type 'text/plain'
  VERSION
end

not_found do
  status 404
  content_type 'text/html', charset: 'utf-8'
  haml :not_found, layout: :layout, locals: merged(
    title: request.url
  )
end

error do
  status 503
  e = env['sinatra.error']
  Raven.capture_exception(e)
  haml(
    :error,
    layout: :layout,
    locals: merged(
      title: 'error',
      error: "#{e.message}\n\t#{e.backtrace.join("\n\t")}"
    )
  )
end

private

def context
  "#{request.ip} #{request.user_agent} #{VERSION} #{Time.now.strftime('%Y/%m')}"
end

def merged(hash)
  out = @locals.merge(hash)
  out[:local_assigns] = out
  if cookies[:flash_msg]
    out[:flash_msg] = cookies[:flash_msg]
    cookies.delete(:flash_msg)
  end
  out
end

def flash(uri, msg)
  cookies[:flash_msg] = msg
  redirect uri
end

def author
  redirect '/hello' unless session[:author]
  Author.new(login: session[:author].downcase, pgsql: settings.pgsql)
end
