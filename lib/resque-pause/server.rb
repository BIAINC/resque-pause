require 'resque'
require 'resque/server'
require File.expand_path(File.join('../','resque_pause_helper'), File.dirname(__FILE__))

# Extends Resque Web Based UI.
# Structure has been borrowed from ResqueScheduler.
module ResquePause
  module Server

    def self.erb_path(filename)
      File.join(File.dirname(__FILE__), 'server', 'views', filename)
    end

    def self.public_path(filename)
      File.join(File.dirname(__FILE__), 'server', 'public', filename)
    end

    def self.included(base)

      base.class_eval do

        helpers do
          def paused?(queue)
            ResquePauseHelper.paused?(queue)
          end
        end

        mime_type :json, 'application/json'

        get '/pause' do
          request.accept.each do |type|
            case type
            when /json/
              hash = Hash[resque.queues.map{|q| [q, ResquePauseHelper.paused?(q)]}]
              content_type :json
              halt(hash.to_json)
            else
              html = erb(File.read(ResquePause::Server.erb_path('pause.erb')))
              halt(html)
            end
          end
        end

        post '/pause' do

          if /json/ =~ request.content_type
            hash = MultiJson.load(request.body.read.to_s)
            params.merge!(hash)
          end
          pause = params['pause'].to_s == "true"

          unless params['queue_name'].empty?
            if pause
              ResquePauseHelper.pause(params['queue_name'])
            else
              ResquePauseHelper.unpause(params['queue_name'])
            end
          end
          content_type :json
          ResquePauseHelper.encode(:queue_name => params['queue_name'], :paused => pause)
        end

        get /pause\/public\/([a-z]+\.[a-z]+)/ do
          send_file ResquePause::Server.public_path(params[:captures].first)
        end
      end
    end

    Resque::Server.tabs << 'Pause'
  end
end

Resque.extend ResquePause
Resque::Server.class_eval do
  include ResquePause::Server
end
