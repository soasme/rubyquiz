require 'rubygems'
require 'bundler'

Bundler.require
$: << File.expand_path('../', __FILE__)

require 'dotenv'
Dotenv.load

require 'set'
require 'singleton'

require 'app/libs'
require 'app/managers'
require 'app/controllers'

class App < Sinatra::Base
  configure do
    enable :logging
    set :threaded, false
  end

  use Quiz::Controllers::Consumer
end
