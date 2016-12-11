module Quiz
  module Controllers
    class Consumer < Sinatra::Base
      configure do
        enable :logging
      end

      HashTag = Quiz::Managers::HashTag.instance

      def success data={}
        json data.merge(code: 0)
      end

      def bad_request message='failed'
        resp = json code: 1, message: message
        halt 400, resp
      end

      before '/consumer/:hashtag/:action' do
        unless HashTag.valid? params[:hashtag]
          bad_request 'Invalid hashtag. Please check your hashtag.'
        end
      end

      after '/consumer/:hashtag/:action' do
        logger.info hashtag: params[:hashtag], action: params[:action]
      end

      error Quiz::Managers::TooManyTracks do
        bad_request 'There are too many consuming hashtags. Please stop some hashtags first.'
      end

      get '/consumer/:hashtag/start' do
        HashTag.follow params[:hashtag]
        success
      end

      get '/consumer/:hashtag/status' do
        status = {}
        status.merge!(HashTag.client.status)
        status.merge!(is_following: HashTag.status(params[:hashtag]))
        success status
      end

      get '/consumer/:hashtag/stop' do
        HashTag.unfollow params[:hashtag]
        success
      end

    end
  end
end

