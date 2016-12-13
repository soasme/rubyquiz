describe "HashTagManager" do
  before do
    ENV['TWEET_STREAM_SERIALIZER'] = 'null'
  end

  def hashtag
    o = Quiz::Managers::HashTag.instance
    o.client = double()
    allow(o.client).to receive(:track)
    allow(o.client).to receive(:tweet)
    allow(o.client).to receive(:stop_stream)
    o
  end

  it "should return false for those invalid hashtags" do
    [
      'in valid', 'invalid.', 'invalid,fail',
      'in#valid', '', 'a'*60,
      '中文', 'にほんご', '한국어',
    ].each do |tag|
      expect(hashtag.valid?(tag)).to be_falsy
    end

    expect(hashtag.valid?('valid')).to be_truthy
  end

  it "should follow hashtags" do
    expect(hashtag.include?('hashtag')).to be_falsy
    hashtag.follow('hashtag')
    expect(hashtag.include?('hashtag')).to be_truthy
  end

  it "should unfollow hashtags" do
    hashtag.follow('hashtag')
    hashtag.unfollow('hashtag')
    expect(hashtag.include?('hashtag')).to be_falsy
  end

  it "should check hashtags' status" do
    hashtag.follow('hashtag')
    expect(hashtag.status('hashtag')).to be_truthy
    hashtag.unfollow('hashtag')
    expect(hashtag.status('hashtag')).to be_falsy
  end

  let(:file_like_object) { double("file like object")  }

  it "should dump the content of the post into file by its name" do
    ENV['TWEET_STREAM_SERIALIZE_DIR'] = '/tmp'
    ENV['TWEET_STREAM_SERIALIZER'] = 'file'
    expect(File).to receive(:open).and_return(file_like_object)

    data = {
      'text': 'the content of the post',
      'entities' => {
        'hashtags' => [
          {
            'text' => 'hashtag'
          }
        ]
      }
    }
    Quiz::Managers::FileSerializer.new.serialize(data)
  end
end
