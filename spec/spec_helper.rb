require 'rack/test'
require 'rspec'
require 'rspec/em'

ENV['RACK_ENV'] = 'test'

require File.expand_path("../../app.rb", __FILE__)

module RSpecMixin
  include Rack::Test::Methods
  def app
    described_class
  end
end

RSpec.configure { |c|
  c.include RSpecMixin
}
