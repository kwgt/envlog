#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'sinatra/base'
require 'puma'
require 'puma/configuration'
require 'puma/events'
require 'yaml'
require 'securerandom'
require 'digest/md5'

module EnvLog
  module Viewer
    class WebServer < Sinatra::Base
      UUID_PATTERN = '\h{8}-\h{4}-\h{4}-\h{4}-\h{12}'

      set :environment, (($develop_mode)? %s{development}: %s{production})
      set :views, APP_RESOURCE_DIR + "views"
      set :threaded, true
      set :quiet, true

      enable :logging

      use Rack::CommonLogger, Log.logger

      configure :development do
        before do
          cache_control :no_store, :no_cache, :must_revalidate,
                        :max_age => 0, :post_check => 0, :pre_check => 0
          headers "Pragma" => "no-cache"
        end
      end

      helpers do
        def app
          return (@app ||= settings.app)
        end

        def find_resource(type, name)
          ret = RESOURCE_DIR + "extern" + type + name
          return ret if ret.exist?

          ret = RESOURCE_DIR + "common" + type + name
          return ret if ret.exist?

          ret = APP_RESOURCE_DIR + type + name
          return ret if ret.exist?

          return nil
        end

        def websock_url
          scheme = (WebServer.use_tls?)? "wss": "ws"
          port   = WebServer.ws_port
          return "#{scheme}://${location.hostname}:#{port}"
        end
      end

      get "/" do
        erb :main
      end

      get %r{/sensor/(#{UUID_PATTERN})} do |id|
        erb :sensor
      end

      get "/js/const.js" do
        content_type("text/javascript")

        <<~EOS
          const WEBSOCK_URL = `#{websock_url}`;
        EOS
      end

      get %r{/css/(.+).scss} do |name|
        p name
        content_type('text/css')
        scss name.to_sym, :views => APP_RESOURCE_DIR + "scss"
      end

      get %r{/(css|js|img|fonts)/(.+)} do |type, name|
        path = find_resource(type, name)
        
        if path
          send_file(path)
        else
          halt 404
        end
      end

      class << self
        def use_auth?
          return Config.has?(:webserver, :auth)
        end

        def use_tls?
          return Config.has?(:webserver, :tls)
        end

        def passwd_file
          return @passwd_file ||= Config.fetch_path(:webserver, :auth)
        end
        private :passwd_file

        def http_port
          return @http_port ||= Config.dig(:webserver, :port, :http)
        end
        private :http_port

        def ws_port
          return @ws_port ||= Config.dig(:webserver, :port, :ws)
        end
        private :http_port

        def bind_addr
          return @bind_addr ||= Config.dig(:webserver, :bind)
        end
        private :bind_addr

        def key_file
          return @key_file ||= Config.fetch_path(:webserver, :tls, :key)
        end
        private :key_file

        def cert_file
          return @cert_file ||= Config.fetch_path(:webserver, :tls, :cert)
        end
        private :key_file

        if WebServer.use_auth?
          def new(*)
            ret = Rack::Auth::Digest::MD5.new(super) {|user| passwd_db[user]}

            ret.realm            = TRADITIONAL_NAME
            ret.opaque           = SecureRandom.alphanumeric(32)
            ret.passwords_hashed = true

            return ret
          end

          def passwd_db
            if not @passwd_db
              @passwd_db ||= YAML.load_file(passwd_file) rescue {}
            end

            return @passwd_db
          end
          private :passwd_db

          def make_a1_string(user, pass)
            ret = Digest::MD5.hexdigest("#{user}:#{TRADITIONAL_NAME}:#{pass}")
            return ret
          end
          private :make_a1_string
        end

        def add_user(user, pass)
          if not use_auth?
            STDERR.print("auth configuraton is not set.\n")
            exit 1
          end

          passwd_db[user] = make_a1_string(user, pass)

          passwd_file.open("w") { |f|
            f.chmod(0o600)
            f.write(passwd_db.to_yaml)
          }
        end

        def bind_url
          if bind_addr.include?(":")
            addr = "[#{bind_addr}]"
          else
            addr = bind_addr
          end

          if use_tls?
            ret = "ssl://#{addr}:#{http_port}?key=#{ssl_key}&cert=#{ssl_cert}"
          else
            ret = "tcp://#{addr}:#{http_port}"
          end

          return ret
        end
        private :bind_url

        def env_string
          return ($develop_mode)? 'development':'production'
        end

        def start(app)
          set :app, app

          config  = Puma::Configuration.new { |user_config|
            user_config.quiet
            user_config.threads(4, 4)
            user_config.bind(bind_url())
            user_config.environment(env_string())
            user_config.force_shutdown_after(-1)
            user_config.app(WebServer)
          }

          @events = Puma::Events.new(Log.device, Log.device)
          @launch = Puma::Launcher.new(config, :events => @events)

          # pumaのランチャークラスでのシグナルのハンドリングが
          # 邪魔なのでオーバライドして無効化する
          def @launch.setup_signals
            # nothing
          end

          @thread = Thread.start {
            begin
              Log.info('webserver') {"started #{bind_url()}"}
              @launch.run
            ensure
              Log.info('webserver') {"stopped"}
            end
          }

          # サーバが立ち上がりきるまで待つ
          booted  = false
          @events.on_booted {booted = true}
          sleep 0.2 until booted
        end

        def stop
          @launch.stop
          @thread.join

          remove_instance_variable(:@launch)
          remove_instance_variable(:@thread)
        end
      end
    end
  end
end
