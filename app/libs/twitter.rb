require 'logger'
require 'json'
require 'simple_oauth'
require 'em-http'

module Twitter
  module StreamingAPI

    LOGGER = Logger.new(STDOUT)

    class ChunkBuilder

      def initialize &block
        @chunks = Array.new
        @next_message_bytes = ''
        @next_message_size = 0
        @next_message_callback = block
      end

      def on_receive_message &block
        @next_message_callback = block
      end

      def next_message
        return nil unless @next_message_bytes

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
          nil
        end
      end

      def receive_chunk chunk
        return if chunk.strip.empty?

        data = chunk.split /[\r\n]+/
        data = data.reject {|e| e.empty?}
        data.each { |elem|
          @chunks.push elem
        }

        if @chunks.size >= 2
          message = build_chunks
          if message
            @next_message_callback.call(message)
            LOGGER.debug action: :received_message,
              expected: @next_message_size,
              bytes: @next_message_bytes.length
            @chunks.clear
            @next_message_size = 0
          else
            LOGGER.debug action: :received_chunk,
              expected: @next_message_size,
              bytes: chunk.length
          end
        end
      end

      def build_chunks
        @next_message_size = @chunks[0].to_i
        received_sizes = @chunks[1,@chunks.length-1].map {|e| e.length}
        received_size = received_sizes.reduce :+

        # A message contains '\r\n' as delimiter. Since we split
        # by '\r\n', we need reduce size by 2 to get actual size.
        if received_size >= @next_message_size - 2
          @next_message_bytes = @chunks[1,@chunks.length-1].join
          @next_message_bytes = @next_message_bytes[0, @next_message_size - 2]
          return next_message
        end
      end
    end

    class Reconnector
      # Once an established connection drops, attempt to reconnect immediately.
      # If the reconnect fails, slow down your reconnect attempts according
      # to the type of error experienced.

      # Back off linearly for TCP/IP level network errors. These
      # problems are generally temporary and tend to clear quickly.
      # Increase the delay in reconnects by 250ms each attempt, up
      # to 16 seconds.
      NETWORK_ERROR_BACKOFF_INITIAL = 0
      NETWORK_ERROR_BACKOFF_DELAY = 0.25
      NETWORK_ERROR_BACKOFF_MAXIMUM = 16

      # Back off exponentially for HTTP errors for which reconnecting
      # would be appropriate. Start with a 5 second wait, doubling each
      # attempt, up to 320 seconds.
      HTTP_ERROR_BACKOFF_INITIAL = 5
      HTTP_ERROR_BACKOFF_MAXIMUM = 320

      # Back off exponentially for HTTP 420 errors. Start with a 1
      # minute wait and double each attempt. Note that every HTTP 420
      # received increases the time you must wait until rate limiting
      # will no longer will be in effect for your account.
      HTTP_420_BACKOFF_INITIAL = 60
      HTTP_420_BACKOFF_MAXIMUM = 480

      ENO = :no
      ENETWORK = :network
      EHTTP = :http
      EHTTP420 = :http420


      def initialize
        @errtype = ENO
        @backoff = 0
        @giveup = false
      end

      def reset errtype
        @errtype = errtype
        @giveup = false
        case @errtype
        when ENO
          @backoff = 0
        when ENETWORK
          @backoff = NETWORK_ERROR_BACKOFF_INITIAL
        when EHTTP
          @backoff = HTTP_ERROR_BACKOFF_INITIAL
        when EHTTP420
          @backoff = HTTP_420_BACKOFF_INITIAL
        end
      end

      def status
        {
          backoff: @backoff,
          errtype: @errtype,
          giveup: @giveup,
        }
      end

      def backoff errtype
        case @errtype
        when ENO
          @backoff = 0
        when ENETWORK
          @backoff += NETWORK_ERROR_BACKOFF_DELAY
          if @backoff > NETWORK_ERROR_BACKOFF_MAXIMUM
            @giveup = true
          end
        when EHTTP
          @backoff *= 2
          if @backoff > HTTP_ERROR_BACKOFF_MAXIMUM
            @giveup = true
          end
        when EHTTP420
          @backoff *= 2
          if @backoff > HTTP_420_BACKOFF_MAXIMUM
            @giveup = true
          end
        end
      end

      def execute errtype, &block
        if errtype == @errtype
          backoff errtype
        else
          reset errtype
        end

        if @giveup
          LOGGER.error action: :giveup_reconnecting,
            errtype: errtype,
            backoff: @backoff
        elsif @backoff == 0
          LOGGER.info action: :reconnect_immediately,
            errtype: errtype
          block.call
        else
          LOGGER.info action: :backoff,
            errtype: @errtype,
            backoff: @backoff
          EM::Timer.new(@backoff, &block)
        end
      end

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

      attr_accessor :term, :conn, :http

      def initialize options
        @options = options
        @chunk_builder = ChunkBuilder.new
        @reconnector = Reconnector.new
        @term = ''
        @errback = nil
        @started = Time.now.utc
        @conn = nil
        @conn_class = options[:conn_class] || EventMachine::HttpRequest
        @filter_url = options[:filter_url] || FILTER_URL
      end

      def on_error &block
        @errback = block
      end

      def tweet &block
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

      def stop_stream
        @conn.close('stop stream connection') if @conn and not @conn.deferred
        @conn = nil
      end

      def receive_callback cb=nil
        if @http.response_header.status == 420
          reconnect Reconnector::EHTTP420
        else
          reconnect Reconnector::EHTTP
        end
      end

      def receive_headers headers
        @code = headers.http_status
      end

      def receive_error e
        if e.class == EventMachine::HttpClient
          if e.error == Errno::ETIMEDOUT
            reconnect Reconnector::ENETWORK
          elsif e.error == "stop stream connection"
            LOGGER.info action: :reschedule, message: e.error
          elsif e.error == "connection closed by server"
            receive_callback
          else
            LOGGER.error action: :handle_error, error: "#{ e.error }"
          end
        else
          LOGGER.error action: :handle_error, error: "#{ e }"
        end
      end

      def receive_stream chunk
        @reconnector.reset Reconnector::ENO
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
        SimpleOAuth::Header.new 'POST', @filter_url, body, @options[:oauth]
      end

      def connect options={}
        @conn_class.new @filter_url,
          :connect_timeout => CONNECT_TIMEOUT,
          :inactivity_timeout => INACTIVITY_TIMEOUT
      end

      def reconnect errtype
        @reconnector.execute errtype do
          send_request(@term) if @term
        end
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


    end
  end
end
