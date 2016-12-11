require 'ostruct'
require 'json'
require 'simple_oauth'
require 'em-http'

module Twitter
  module StreamingAPI

    class TrackClient

      HOST = "stream.twitter.com"
      BASE_URL = "https://#{ HOST  }"
      FILTER_URL = "#{ BASE_URL }/1.1/statuses/filter.json"
      VERSION = "0.1.0"
      CONTENT_TYPE = "application/x-www-form-urlencoded"
      USER_AGENT = "RubyQuiz-Streaming-Client #{ VERSION }"
      ACCEPT_ENCODINGS = ['deflate', 'gzip']
      TRANSFER_ENCODING = "chunked"
      NEWLINE = /[\r\n]+/

      LOGGER = Logger.new(STDOUT)

      def initialize options
        @options = options
        @term = ''
        @delimited_length = 0
        @stream = ''
        @errback = nil
        @code = 0
        @shutdown = false
        @started = Time.now.utc
        @conn = nil
        @reconnect_sleep = 0
        @track_block = nil
      end

      def connect options={}
        EventMachine::HttpRequest.new FILTER_URL
      end

      def on_error &block
        @errback = block
      end

      def reset
        @code = 0
        @delimited_length = 0
        @stream = ''
      end

      def stop_stream
        @conn.close('stop stream connection') if @conn and not @conn.deferred
        @conn = nil
        reset
      end

      def send_request(term, &block)
        stop_stream if @conn
        @conn = connect
        @http = @conn.post body: body, head: head
        @http.stream { |chunk| receive_stream(chunk, &block) }
        @http.headers &method(:receive_headers)
        @http.errback &method(:receive_error)
        @http.callback {
          LOGGER.error action: :http_callback, status: @http.response_header.status,
            headers: @http.response_header
        }
      end

      def track term, &block
        @term = term
        @track_block = block
        if @term
          send_request @term, &block
        end
      end

      def receive_headers headers
        @code = headers.http_status
      end

      def reconnect
        if @reconnect_sleep == 0
          track @term, &@track_block
        end
      end

      def receive_error e
        if e.class == EventMachine::HttpClient
          if e.error == Errno::ETIMEDOUT
            LOGGER.warn action: :reconnect, error: "Errno::ETIMEDOUT"
            reconnect
          else
            LOGGER.error action: :handle_error, error: "#{ e.error }"
          end
        else
          LOGGER.error action: :handle_error, error: "#{ e }"
        end
      end

      def receive_stream chunk, &block
        if chunk.strip.empty?
          @delimited_length = 0
          @stream = ''
          return
        end

        data = chunk.split NEWLINE
        LOGGER.debug action: :receive_chunk, bytes: chunk.length

        if data.size == 2
          @delimited_length = 0
          @stream = ''
          delimited_length, first_chunk = data
          @delimited_length = delimited_length.to_i
          @stream << first_chunk
        else
          @stream << chunk
        end
        if @delimited_length > 0 and @delimited_length <= @stream.length
          obj = parsed_stream
          if obj
            hashtags = obj['entities']['hashtags']
            hashtags = hashtags.map { |x| x['text'] }
            hashtags = hashtags.join(',')
            LOGGER.info action: :receive_message, bytes: @stream.length, hashtags: hashtags
            block.call obj
          end
        end
      end

      def status
        {
          uptime: Time.now.utc - @started,
          tracking_terms: @term,
        }
      end

      def parsed_stream
        @stream.strip!
        begin
          JSON.parse(@stream)
        rescue JSON::ParserError
          LOGGER.error action: :parse_stream, stream: @stream
        end
      end

      def body
        {
          track: @term,
          delimited: 'length',
        }
      end

      def head
        {
          "Host" => HOST,
          "Content-Type" => CONTENT_TYPE,
          "Accept-Encoding" => ACCEPT_ENCODINGS.join(','),
          "User-Agent" => USER_AGENT,
          "Authorization" => "#{ authorization }",
        }
      end

      def authorization
        SimpleOAuth::Header.new 'POST', FILTER_URL, body, @options[:oauth]
      end

    end
  end
end
