module Quiz
  module Managers

    class TooManyTracks < StandardError
    end

    class BaseTweetSerializer
      def dump(tag, status)
        # rewrite me.
      end

      def serialize(status, &filter)
        unless status && status.class == Hash && status['entities'] && \
            status['entities']['hashtags']
          return
        end
        status['entities']['hashtags'].each do |tag|
          if tag and tag['text'] and filter.call(tag['text'])
            dump(tag['text'], status)
          end
        end
      end
    end

    class ConsoleSerializer < BaseTweetSerializer
      def dump(tag, status)
        puts "====> #{ tag }"
        puts "@#{ status["user"]["name"]}: #{ status['text']}\n#{ status['created_at ']}\n"
      end
    end

    class FileSerializer < BaseTweetSerializer
      def dump(tag, status)
        filename = ENV['TWEET_STREAM_SERIALIZE_DIR'] + '/' + tag.downcase
        open(filename, 'a') do |f|
          f << "#{ status['text'] }\n"
        end
      end
    end

    class HashTag

      include Singleton

      attr_reader :client

      MAXIMUM = 100
      CLIENT_OPTIONS = {
        oauth: {
          consumer_key: ENV['TWITTER_CONSUMER_KEY'],
          consumer_secret: ENV['TWITTER_CONSUMER_SECRET'],
          token: ENV['TWITTER_ACCESS_TOKEN'],
          token_secret: ENV['TWITTER_ACCESS_TOKEN_SECRET']
        }
      }

      def initialize
        # FIXME: Instead of in-memory implement,
        # Read/Write phrases into database to archive a persistence goal.
        @phrases = Set.new

        # Initialize a streaming api client.
        @client = Twitter::StreamingAPI::TrackClient.new CLIENT_OPTIONS

      end

      def serializer
        # Set TWEET_STREAM_SERIALIZER to `file` to dump tweets into files grouped by tag.
        # Set TWEET_STREAM_SERIALIZER to `console` to puts the content of tweet to STDOUT.
        case ENV['TWEET_STREAM_SERIALIZER']
        when 'console' then ConsoleSerializer.new
        when 'file' then FileSerializer.new
        else ConsoleSerializer.new
        end
      end


      def format(hashtag)
        # Hashtag should be insensitive
        hashtag = hashtag.downcase
        return "#" + hashtag.downcase
      end


      def valid? hashtag
        # No space in hashtag
        return false if hashtag.include? ' '

        # Punctuation is not considered to be part of a #hashtag mention,
        # so a track term containing punctuation will not match #hashtag.
        return false if hashtag.include? '.'

        # A comma-separated list of phrases which will be used to determine
        # what Tweets will be delivered on the stream.
        # So, comma is not allowed in hashtag.
        return false if hashtag.include? ','

        # Each phrase must be between 1 and 60 bytes, inclusive.
        # Since we track #hashtag, so this number would be between 1 and 59 bytes, inclusive.
        return false if hashtag.length < 1 and hashtag.length > 59

        # Non-space separated languages, such as CJK are currently unsupported.
        return false if !!(hashtag =~ /\p{Han}|\p{Katakana}|\p{Hiragana}|\p{Hangul}/)

        true
      end

      def raw_phrases
        # A comma-separated list of phrases which will be used to
        # determine what Tweets will be delivered on the stream.
        @phrases.to_a.join ','
      end

      def include? hashtag
        @phrases.include? format(hashtag)
      end

      def empty?
        @phrases.size == 0
      end

      def overwhelm?
        @phrases.size >= MAXIMUM
      end

      def follow(hashtag, &block)
        raise TooManyTracks if overwhelm?
        term = format(hashtag)
        @phrases.add term
        reload(&block)
      end

      def unfollow(hashtag, &block)
        term = format(hashtag)
        @phrases.delete term
        reload(&block)
      end

      def status(hashtag)
        term = format(hashtag)
        return @phrases.include? term
      end

      def reload(&block)
        phrases = raw_phrases
        if phrases.empty?
          @client.stop_stream
        else
          @client.track raw_phrases

          @client.tweet { |tweet|
            serializer.serialize(tweet) {|tag| include? tag }
          }
        end
      end
    end
  end
end
