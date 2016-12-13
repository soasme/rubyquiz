require 'spec_helper'

describe "Consumer API" do

  it "should halt on invalid hashtag" do
    expect(Quiz::Managers::HashTag.instance).to receive(:valid?).and_return(false)
    get '/consumer/invalid_hashtag/start'
    expect(last_response.status).to eq(400)
  end

  it "should halt on following too many hashtags" do
    expect(Quiz::Managers::HashTag.instance).to receive(:follow).and_raise(Quiz::Managers::TooManyTracks)
    get '/consumer/invalid_hashtag/start'
    expect(last_response.status).to eq(400)
  end

  it "should start following hashtags" do
    expect(Quiz::Managers::HashTag.instance).to receive(:follow).and_return(true)
    get '/consumer/invalid_hashtag/start'
    expect(last_response.status).to eq(200)
  end

  it "should stop from following hashtags" do
    expect(Quiz::Managers::HashTag.instance).to receive(:unfollow).and_return(true)
    get '/consumer/invalid_hashtag/stop'
    expect(last_response.status).to eq(200)
  end

  it "should check following status" do
    expect(Quiz::Managers::HashTag.instance).to receive(:status).and_return(true)
    get '/consumer/invalid_hashtag/status'
    expect(last_response.status).to eq(200)
  end
end
