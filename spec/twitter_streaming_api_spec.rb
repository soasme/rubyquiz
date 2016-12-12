#require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'spec_helper'

describe 'Twitter::StreamingAPI' do
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
