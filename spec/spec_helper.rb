require 'rack/test'
require 'rspec'
require 'rspec/em'
require 'webmock/rspec'

ENV['RACK_ENV'] = 'test'

require File.expand_path("../../app.rb", __FILE__)

module RSpecMixin
  include Rack::Test::Methods
  def app
    App
  end
end

RSpec.configure { |c|
  c.include RSpecMixin
}
