#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'sinatra/base'
require 'thin/logging'
require 'yaml'
require 'securerandom'
require 'digest/md5'

module EnvLog
  module Viewer
    class WebServer < Sinatra::Base
      UUID_PATTERN = '\h{8}-\h{4}-\h{4}-\h{4}-\h{12}'

      configure do
      end

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

        #
        # 以下erb内から使用する為のヘルパー関数
        #

        def render_icon(name)
          ret = <<~EOT
            <svg class="bi">
              <use xlink:href="/icons/bootstrap-icons.svg##{name}"/>
            </svg>
          EOT

          return ret
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
        content_type('text/css')
        scss name.to_sym, :views => APP_RESOURCE_DIR + "scss"
      end

      get %r{/(css|js|img|fonts|icons)/(.+)} do |type, name|
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
          return @key_file ||= Config.fetch_path(:webserver, :tls, :key).to_s
        end
        private :key_file

        def cert_file
          return @cert_file ||= Config.fetch_path(:webserver, :tls, :cert).to_s
        end
        private :cert_file

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
          addr = IPAddr.new(bind_addr)
          str  = (addr.ipv6?)? "[#{addr.to_s}]":addr.to_s 

          return "#{(use_tls?)? "tls":"tcp"}://#{str}:#{http_port}"
        end
        private :bind_url

        def env_string
          return ($develop_mode)? 'development':'production'
        end

        def start(app)
          set :app, app
          set :environment, env_string
          set :bind, bind_addr
          set :port, http_port
          set :views, APP_RESOURCE_DIR + "views"
          set :server, %w[HTTP thin]
          set :threaded, true
          set :quiet, true

          Thin::Logging.silent = true

          use Rack::CommonLogger, Log.logger

          EM.defer {
            sleep 1 until EM.reactor_running?

            sigint = trap(:INT) {}
            sigtrm = trap(:TERM) {}

            Log.info("webserver") {"started (#{bind_url})"}

            run! { |server|
              if use_tls?
                ssl_options = {
                  :private_key_file => key_file,
                  :cert_chain_file  => cert_file,
                  :verify_peer      => false
                }

                server.ssl         = true
                server.ssl_options = ssl_options
              end
            }

            trap(:INT) {sigint.()}
            trap(:TERM) {sigtrm.()}
          }
        end

        def stop
          Log.info("webserver") {"exit"}
        end
      end
    end
  end
end
