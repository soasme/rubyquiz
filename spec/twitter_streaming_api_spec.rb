#require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'spec_helper'

describe 'Twitter::StreamingAPI' do

  Twitter::StreamingAPI::LOGGER.level = Logger::FATAL

  describe 'ChunkBuilder' do

    it "should build message from one chunk" do
      builder = Twitter::StreamingAPI::ChunkBuilder.new {|message|
        expect(message).to eq({"k" => "v"})
      }
      builder.receive_chunk "12\r\n{\"k\": \"v\"}\r\n"
    end

    it "should build message from two chunks" do
      builder = Twitter::StreamingAPI::ChunkBuilder.new {|message|
        expect(message).to eq({"k" => "v"})
      }
      builder.receive_chunk "12\r\n{\"k\""
      builder.receive_chunk ": \"v\"}\r\n"
    end

    it "should build message from multiline" do
      builder = Twitter::StreamingAPI::ChunkBuilder.new {|message|
        expect(message).to eq({"k" => "v"})
      }
      builder.receive_chunk "12\r\n{\"k\": \"v\"}\r\nExceeded connection limit for user\r\n"
    end
  end

  describe "Reconnector" do

    include RSpec::EM::FakeClock

    before { clock.stub  }
    after { clock.reset  }

    it "should reconnect immediately on network error" do
      reconnector = Twitter::StreamingAPI::Reconnector.new
      reconnector.execute :network do end
      expect(reconnector.status).to eq({backoff: 0, errtype: :network, giveup: false})
    end

    it "should backoff linearly on network error happened again" do
      reconnector = Twitter::StreamingAPI::Reconnector.new
      65.times do |i|
        reconnector.execute :network do end
        clock.tick(0.25 * i)
        expect(reconnector.status[:giveup]).to be_falsy
        expect(reconnector.status[:backoff]).to eq(0.25 * i)
      end
    end

    it "should halt from 16 seconds' waiting on network error" do
      reconnector = Twitter::StreamingAPI::Reconnector.new
      65.times do |i| reconnector.execute :network do end end
      reconnector.execute :network do
        fail "this should not be called!"
      end
      clock.tick(17)
      expect(reconnector.status[:giveup]).to be_truthy
    end

    it "should backoff exponentiall on http error" do
      reconnector = Twitter::StreamingAPI::Reconnector.new
      7.times do |i|
        reconnector.execute :http do end
        time = 5 * (2 ** i)
        clock.tick(time)
        expect(reconnector.status).to eq({backoff: time, errtype: :http, giveup: false})
      end
    end

    it "should halt from 320 seconds' waiting on http error" do
      reconnector = Twitter::StreamingAPI::Reconnector.new
      7.times do |i| reconnector.execute :http do end end
      reconnector.execute :http do
        fail "this should not be called!"
      end
      expect(reconnector.status[:giveup]).to be_truthy
    end

    it "should backoff exponentially on http 420 error" do
      reconnector = Twitter::StreamingAPI::Reconnector.new
      4.times do |i|
        reconnector.execute :http420 do end
        time = 60 * (2 ** i)
        clock.tick(time)
        expect(reconnector.status).to eq({backoff: time, errtype: :http420, giveup: false})
      end
    end

    it "should halt from 480 seconds' waiting on http error" do
      reconnector = Twitter::StreamingAPI::Reconnector.new
      4.times do |i| reconnector.execute :http420 do end end
      reconnector.execute :http420 do
        fail "this should not be called"
      end
      expect(reconnector.status[:giveup]).to be_truthy
    end

  end

end

describe 'Twitter::StrreamingAPI::TrackClient' do
  it "should connect to twitter json stream with oauth authorization" do
  end

  it "should track tags " do
  end

  it "should parse json stream" do
  end

  it "should build chunks into message" do
  end

  it "should reconnect immediately on timeout" do
  end

  it "should stop reconnecting on maximum attemps" do
  end

  it "should stop stream" do
  end
end
