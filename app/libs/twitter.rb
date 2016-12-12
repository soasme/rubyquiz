require 'ostruct'
require 'json'
require 'simple_oauth'
require 'em-http'

module Twitter
  module StreamingAPI

    LOGGER = Logger.new(STDOUT)

    class ChunkBuilder

      def initialize &block
        @next_message_bytes = ''
        @next_message_size = 0
        @next_message_callback = nil
      end

      def on_receive_message &block
        @next_message_callback = block
      end

      def next_message
        begin
          # The individual messages streamed by this API are JSON encoded.  
          message = JSON.parse(@next_message_bytes)

          # Messages contains "delete" indicate that a given Tweet has been deleted. 
          # Since RubyQuiz is a realtime application append data to file,
          # we simply ignore this kind of message.
          return nil if message.include?("delete")  || message.include?("location")

          # Messages indicate that a filtered stream has matched more Tweets than 
          # its current rate limit allows to be delivered. 
          # Ignore it.
          return nil if message.include?("limit")

          return message
        rescue JSON::ParserError
          # JSON parser should tolerate unexpected or missing fields.
          LOGGER.error action: :parse_stream, stream: @next_message_bytes
        end
      end

      def receive_chunk chunk
        # On slow streams, some messages may be blank lines which serve
        # as “keep-alive” signals to prevent clients and other network
        # infrastructure from assuming the stream has stalled and closing
        # the connection.
        return if chunk.strip.empty?

        data = chunk.split /[\r\n]+/
        data = data.reject {|e| e.empty?}

        if data.size == 1
          @next_message_bytes << chunk
          LOGGER.debug action: :continue_receiving_message, bytes: @next_message_bytes.length
        else
          # By passing delimited=length, each message will be preceded by a
          # string representation of a base-10 integer indicating the length
          # of the message in bytes.

          # In this case, we clear old state and begin new one.
          @next_message_size, @next_message_bytes = 0, ''

          @next_message_size = data[0].to_i
          @next_message_bytes << data[1]

          LOGGER.debug action: :start_receiving_message, expected: @next_message_size,
            bytes: @next_message_bytes.length
        end


        if @next_message_size > 0 && @next_message_size <= @next_message_bytes.length
          obj = next_message
          if obj
            @next_message_callback.call(obj)
            LOGGER.debug action: :end_receiving_message, bytes: @next_message_bytes.length
          else
            LOGGER.debug action: :cancle_receiving_message, bytes: @next_message_bytes.length
          end
        end

      end
    end

    class Connectify
    end


    class TrackClient

      HOST = "stream.twitter.com"
      BASE_URL = "https://#{ HOST  }"
      FILTER_URL = "#{ BASE_URL }/1.1/statuses/filter.json"
      VERSION = "0.1.0"
      CONTENT_TYPE = "application/x-www-form-urlencoded"
      USER_AGENT = "RubyQuiz-Streaming-Client #{ VERSION }"
      ACCEPT_ENCODINGS = ['deflate', 'gzip']
      TRANSFER_ENCODING = "chunked"
      CONNECT_TIMEOUT = 90
      INACTIVITY_TIMEOUT = 90

      def initialize options
        @options = options
        @chunk_builder = ChunkBuilder.new
        @term = ''
        @errback = nil
        @started = Time.now.utc
        @conn = nil
      end

      def on_error &block
        @errback = block
      end

      def on_tweet &block
        @chunk_builder.on_receive_message &block
      end

      # TODO: We need to add rate limit for client.Clients which make excessive
      # connection attempts (both successful and unsuccessful) run the risk of
      # having their IP automatically banned.
      def track term
        @term = term
        if @term
          send_request @term
        end
      end

      def status
        {
          uptime: Time.now.utc - @started,
          tracking_terms: @term,
        }
      end


      private

      def receive_callback
        LOGGER.error action: :http_callback, status: @http.response_header.status,
          headers: @http.response_header
      end

      def receive_headers headers
        @code = headers.http_status
      end

      def receive_error e
        if e.class == EventMachine::HttpClient
          if e.error == Errno::ETIMEDOUT
            LOGGER.warn action: :reconnect, error: "Errno::ETIMEDOUT"
            reconnect
          elsif e.error == "stop stream connection"
            LOGGER.info action: :reschedule, message: e.error
          else
            LOGGER.error action: :handle_error, error: "#{ e.error }"
          end
        else
          LOGGER.error action: :handle_error, error: "#{ e }"
        end
      end

      def receive_stream chunk
        @chunk_builder.receive_chunk chunk
      end

      def body
        {
          track: @term,
          delimited: 'length',
        }
      end

      # Read chapter "Gzip and EventMachine" at
      # https://dev.twitter.com/streaming/overview/processing
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

      def connect options={}
        EventMachine::HttpRequest.new FILTER_URL,
          :connect_timeout => CONNECT_TIMEOUT,
          :inactivity_timeout => INACTIVITY_TIMEOUT
      end

      def reconnect
        send_request @term if @term
      end

      def send_request term
        # Twitter Policy: Each account may create only one standing connection
        # to the public endpoints, and connecting to a public stream more than
        # once with the same account credentials will cause the oldest connection
        # to be disconnected.
        #
        # So, We have to stop stream first and then create a new connection.
        stop_stream if @conn

        @conn = connect
        @http = @conn.post body: body, head: head
        @http.stream  &method(:receive_stream)
        @http.headers &method(:receive_headers)
        @http.errback &method(:receive_error)
        @http.callback &method(:receive_callback)
      end

      def stop_stream
        @conn.close('stop stream connection') if @conn and not @conn.deferred
        @conn = nil
      end

    end
  end
end
