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
require 'backtrace'
require 'raven'
require 'omniauth-twitter'
require_relative 'version'
require_relative 'objects/tbot'
require_relative 'objects/author'
require_relative 'objects/audits'
require_relative 'objects/audit'
require_relative 'objects/pings'

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
    'sentry' => '',
    'telegram_token' => ''
  }
  config = YAML.safe_load(File.open(File.join(File.dirname(__FILE__), 'config.yml'))) unless ENV['RACK_ENV'] == 'test'
  if ENV['RACK_ENV'] != 'test'
    Raven.configure do |c|
      c.dsn = config['sentry']
      c.release = VERSION
    end
  end
  enable :sessions
  set :views, File.dirname(__FILE__) + '/views'
  set :public_folder, File.dirname(__FILE__) + '/public'
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
  set :tbot, Tbot.new(token: config['telegram_token'], pgsql: settings.pgsql)
  use OmniAuth::Builder do
    provider :twitter, config['twitter']['api_key'], config['twitter']['api_secret']
  end
  if ENV['RACK_ENV'] != 'test'
    Thread.new do
      settings.tbot.start
    end
    Thread.new do
      loop do
        begin
          Audits.new(pgsql: settings.pgsql).each { |a| a.deliver(settings.tbot) }
          Pings.new(pgsql: settings.pgsql).each { |p| p.deliver(settings.tbot) }
        rescue StandardError => e
          puts Backtrace.new(e)
        end
        sleep(60)
      end
    end
  end
end

before '/*' do
  @locals = {
    ver: VERSION,
    request_ip: request.ip
  }
  session[:author] = 'tester' if ENV['RACK_ENV'] == 'test'
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
    inbox: author.inbox,
    telegram: settings.tbot.identified?(author.login)
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
  soalition = author.soalitions.one(params[:id].to_i)
  post = soalition.share(author.login, params[:uri])
  soalition.members(admins_only: true).each do |user|
    next if user == author.login
    settings.tbot.notify(
      user,
      [
        "A [new post](#{post.uri}) has been shared by `@#{author.login}` in",
        "[#{soalition.name}](https://www.soalition.com/soalition?id=#{soalition.id}),",
        "you may want to [approve](https://www.soalition.com/do-approve?id=#{post.id})",
        "or [reject](https://www.soalition.com/do-reject?id=#{post.id}) it."
      ].join(' ')
    )
  end
  flash("/soalition?id=#{soalition.id}", "Your post was shared to the soalition ##{soalition.id}")
end

get '/join' do
  id = params[:id].to_i
  flash("/soalition?id=#{id}", 'You are a member already') if author.soalitions.member?(id)
  soalition = author.soalitions.join(id)
  soalition.members(admins_only: true).each do |user|
    next if user == author.login
    settings.tbot.notify(
      user,
      [
        "A new member `@#{author.login}` joined",
        "[#{soalition.name}](https://www.soalition.com/soalition?id=#{soalition.id})."
      ].join(' ')
    )
  end
  flash("/soalition?id=#{soalition.id}", "You have successfully joined soalition ##{soalition.id}")
end

get '/do-approve' do
  post = author.post(params[:id].to_i)
  post.approve(author.login)
  soalition = post.soalition
  settings.tbot.notify(
    post.author,
    [
      "Your [post](#{post.uri}) has been approved by `@#{author.login}` in",
      "[#{soalition.name}](https://www.soalition.com/soalition?id=#{soalition.id})."
    ].join(' ')
  )
  soalition.members.each do |user|
    next if user == author.login
    next if user == post.author
    settings.tbot.notify(
      user,
      [
        "A [new post](#{post.uri}) has been shared by `@#{post.author}` in",
        "[#{soalition.name}](https://www.soalition.com/soalition?id=#{soalition.id}),",
        "you may want to [re-post](https://www.soalition.com/repost?id=#{post.id}) it",
        'and earn a few reputation points.'
      ].join(' ')
    )
  end
  flash('/', "The post of @#{post.author} has been approved")
end

get '/do-reject' do
  post = author.post(params[:id].to_i)
  soalition = post.soalition
  uri = post.uri
  owner = post.author
  if author.login != owner
    settings.tbot.notify(
      owner,
      [
        "Your [post](#{uri}) has been rejected by `@#{author.login}` in",
        "[#{soalition.name}](https://www.soalition.com/soalition?id=#{soalition.id})."
      ].join(' ')
    )
  end
  post.reject(author.login)
  flash('/', "The post of @#{owner} has been rejected")
end

get '/approve-repost' do
  post = author.post(params[:post].to_i)
  soalition = post.soalition
  friend = post.reposts.approve(params[:id].to_i, author.login)
  settings.tbot.notify(
    friend,
    [
      "Your repost of [this post](#{post.uri}) has been approved by `@#{author.login}` in",
      "[#{soalition.name}](https://www.soalition.com/soalition?id=#{soalition.id})."
    ].join(' ')
  )
  flash('/', "The repost of the post ##{post.id} has been approved")
end

get '/reject-repost' do
  post = author.post(params[:post].to_i)
  soalition = post.soalition
  friend = post.reposts.reject(params[:id].to_i, author.login)
  settings.tbot.notify(
    friend,
    [
      "Your repost of [this post](#{post.uri}) has been rejected by `@#{author.login}` in",
      "[#{soalition.name}](https://www.soalition.com/soalition?id=#{soalition.id})."
    ].join(' ')
  )
  flash('/', "The repost of the post ##{post.id} has been rejected.")
end

get '/repost' do
  post = author.post(params[:id].to_i)
  raise 'You can\'t repost your own post' if post.author == author.login
  haml :repost, layout: :layout, locals: merged(
    title: '/repost',
    post: post
  )
end

post '/do-repost' do
  post = author.post(params[:id].to_i)
  raise 'You can\'t repost your own post' if post.author == author.login
  id = post.reposts.submit(author.login, params[:uri])
  settings.tbot.notify(
    post.author,
    [
      "Your [post](#{post.uri}) has been reposted by `@#{author.login}`",
      "[here](#{params[:uri]}),",
      "please [approve](https://www.soalition.com/approve-repost?id=#{id}&post=#{post.id})",
      "or [reject](https://www.soalition.com/reject-repost?id=#{id}&post=#{post.id}) it."
    ].join(' ')
  )
  flash(
    "/soalition?id=#{post.soalition.id}",
    "Your contribution to the post of @#{post.author} has been submitted"
  )
end

get '/soalition' do
  soalition = author.soalitions.one(params[:id].to_i)
  haml :soalition, layout: :layout, locals: merged(
    title: "##{soalition.id}",
    soalition: soalition
  )
end

get '/audit' do
  soalition = author.soalitions.one(params[:id].to_i)
  audit = Audit.new(id: soalition.id, pgsql: settings.pgsql)
  haml :audit, layout: :layout, locals: merged(
    title: "##{soalition.id}",
    soalition: soalition,
    audit: audit
  )
end

get '/quit' do
  soalition = author.soalitions.one(params[:id].to_i)
  soalition.quit(author.login)
  soalition.members(admins_only: true).each do |user|
    next if user == author.login
    settings.tbot.notify(
      user,
      [
        "A member `@#{author.login}` just quit",
        "[#{soalition.name}](https://www.soalition.com/soalition?id=#{soalition.id})."
      ].join(' ')
    )
  end
  flash('/', 'You are out, we are sorry :(')
end

get '/tbot' do
  settings.tbot.identify(author.login, params[:chat].to_i)
  flash('/', 'Thanks, now I know who you are in Telegram!')
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
      error: Backtrace.new(e).to_s
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
