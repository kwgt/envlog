#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'em-websocket'
require 'msgpack/rpc/server'

module EnvLog
  module Viewer
    class WebSocket
      include MessagePack::Rpc::Server

      msgpack_options :symbolize_keys => true

      class << self
        #
        # セッションリストの取得
        #
        # @return [Array<WebSocket>] セッションリスト
        #
        def session_list
          return @session_list ||= []
        end
        private :session_list

        #
        # クリティカルセクションの設置
        #
        # @yield クリティカルセクションとして処理するブロック
        #
        # @return [Object] ブロックの戻り値
        #
        def sync(&proc)
          return (@mutex ||= Mutex.new).synchronize(&proc)
        end

        #
        # セッションリストへのセッション追加
        #
        # @param [Socket] sock  セッションリストに追加するソケットオブジェクト
        #
        # @return [WebSocket]
        #   ソケットオブジェクトに紐付けられたセッションオブジェクト
        #
        # @note
        #   受け取ったソケットオブジェクトを元に、セッションオブジェクトを
        #   生成し、そのオブジェクトをセッションリストに追加する
        #
        def join(sock)
          sync {
            if session_list.any? {|s| s === sock}
              raise("Already joined #{sock}")
            end

            ret = self.new(@app, sock)
            session_list << ret

            return ret
          }
        end
        private :join

        #
        # セッションオブジェクトからのセッション削除
        #
        # @param [Socket] sock
        #   セッションオブジェクトを特定するためのソケットオブジェクト
        #
        def bye(sock)
          sync {
            session_list.reject! { |s|
              if s === sock
                s.finish
                true
              else
                false
              end
            }
          }
        end

        #
        # イベント情報の一斉送信
        #
        # @param [String] name  イベント名
        # @param [Array] args イベントで通知する引数
        #
        def broadcast(name, *args)
          sync {session_list.each {|s| s.notify(name, *args)}}
        end

        #
        # コンフィギュレーションデータからバインドアドレスを読み出す
        #
        # @return [String] バインドアドレスを表す文字列
        #
        def bind_addr
          return @bind_addr ||= Config.dig(:webserver, :bind)
        end
        private :bind_addr

        #
        # TSLを使用するかどうかをコンフィギュレーションデータから判定する
        #
        # @return [boolean] TSLを使用する場合はtrue、使用しない場合はfalse
        #
        def use_tsl?
          return Config.has?(:webserver, :tsl)
        end

        #
        # WebSoketに使用するポート番号をコンフィギュレーションから読み出す
        #
        # @return [Integer] WeoSocketで使用するポート番号
        #
        def ws_port
          return @ws_port ||= Config.dig(:webserver, :port, :ws)
        end

        #
        # 証明書ファイルのパスをコンフィギュレーションデータか読み出す
        #
        # @return [Pathname] 証明書ファイルのパス
        #
        def cert_file
          return @cert_file ||= Config.fetch_path(:webserver, :tsl, :cert)
        end

        #
        # サーバ鍵ファイルのパスをコンフィギュレーションから読み出す
        #
        # @return [Pathname] 鍵ファイルのパス
        #
        def key_file
          return @key_file ||= Config.fetch_path(:webserver, :tsl, :key)
        end

        #
        # バインド先のURL文字列を生成する
        #
        # @return [String] URL文字列
        #
        def bind_url
          if bind_addr.include?(":")
            addr = "[#{bind_addr}]"
          else
            addr = bind_addr
          end

          return "#{(use_tsl?)? "ssl":"tcp"}://#{addr}:#{ws_port}"
        end
        private :bind_url

        #
        # WebSocket制御の開始
        #
        def start(app)
          EM.defer {
            @app = app

            sleep 1 until EM.reactor_running?

            Log.info("websock") {"started (#{bind_url()})"}

            opts = {
              :host        => bind_addr,
              :port        => ws_port,
              :secure      => use_tsl?,
              :tls_options => {
                :private_key_file => key_file,
                :cert_chain_file  => cert_file
              }
            }

            EM::WebSocket.start(opts) { |sock|
              peer = Socket.unpack_sockaddr_in(sock.get_peername)
              addr = peer[1]
              port = peer[0]
              serv = join(sock)

              sock.set_sock_opt(Socket::Constants::SOL_SOCKET,
                                Socket::SO_KEEPALIVE,
                                true)

              sock.set_sock_opt(Socket::IPPROTO_TCP,
                                Socket::TCP_QUICKACK,
                                true)

              sock.set_sock_opt(Socket::IPPROTO_TCP,
                                Socket::TCP_NODELAY,
                                false)

              sock.onopen {
                Log.info("websock") {"connection from #{addr}:#{port}"}
              }

              sock.onbinary { |msg|
                begin
                  serv.receive_dgram(msg)

                rescue => e
                  Log.error("websock") {
                    "error occured: #{e.message} (#{e.backtrace[0]})"
                  }
                end
              }

              sock.onclose {
                Log.info("websock") {
                  "connection close from #{addr}:#{port}"
                }

                bye(sock)
              }
            }
          }
        end
      end

      #
      # セッションオブジェクトのイニシャライザ
      #
      # @param [IPCam] app  アプリケーション本体のインスタンス
      # @param [Socket] sock Socketインスタンス
      #
      def initialize(app, sock)
        @app   = app
        @sock  = sock
        @allow = []

        peer   = Socket.unpack_sockaddr_in(sock.get_peername)
        @addr  = peer[1]
        @port  = peer[0]
      end

      attr_reader :sock

      #
      # セッションオブジェクトの終了処理
      #
      def finish
      end

      #
      # peerソケットへのデータ送信
      #
      # @param [String] data  送信するデータ
      #
      # @note MessagePack::Rpc::Serverのオーバーライド
      #
      def send_data(data)
        @sock.send_binary(data)
      end
      private :send_data

      #
      # MessagePack-RPCのエラーハンドリング
      #
      # @param [StandardError] e  発生したエラーの例外オブジェクト
      #
      # @note MessagePack::Rpc::Serverのオーバーライド
      # 
      def on_error(e)
        Log.error("websock") {e.message}
      end
      private :on_error

      #
      # 通知のブロードキャスト
      #
      # @param [String] name  イベント名
      # @param [Array] args イベントで通知する引数
      #
      def broadcast(name, *args)
        self.class.broadcast(name, *arg)
      end
      private :broadcast

      #
      # 通知の送信
      #
      # @param [String] name  イベント名
      # @param [Array] args イベントで通知する引数
      #
      def notify(name, *args)
        super(name, *args) if @allow == "*" or @allow.include?(name)
      end

      #
      # 比較演算子の定義
      #
      def ===(obj)
        return (self == obj || @sock == obj)
      end

      #
      # RPC procedures
      #

      #
      # 通知要求を設定する
      #
      # @param [Array] arg
      #
      # @return [:OK] 固定値
      #
      def add_notify_request(*args)
        args.each {|type| @allow << type.to_sym}
        args.uniq!

        return :OK
      end
      remote_public :add_notify_request

      #
      # 通知要求をクリアする
      #
      # @param [Array] arg
      #
      # @return [:OK] 固定値
      #
      def clear_notify_request(*args)
        args.each {|type| @allow.delete(type.to_sym)}

        return :OK
      end
      remote_public :clear_notify_request

      #
      # 疎通確認用プロシジャー
      #
      # @return [:OK] 固定値
      #
      def hello
        return :OK
      end
      remote_public :hello

      #
      # センサー一覧の取得
      #
      # @return [Array<Hash>] センサー情報を列挙した配列
      #
      def get_sensor_list(df)
        EM.defer {
          begin
            db = DBA.open
            df.resolve(db.get_sensor_list())

          rescue => e
            df.reject(e)

          ensure
            db&.close
          end
        }
      end
      remote_async :get_sensor_list

      #
      # 指定されたセンサーの最新の計測値を取得する
      #
      # @param [String] id  センサーのID
      # @return [Hash] 計測値を格納したHash
      #
      def get_latest_sensor_value(df, id)
        EM.defer {
          begin
            db = DBA.open
            df.resolve(db.get_latest_value(id))

          rescue => e
            df.reject(e)

          ensure
            db&.close
          end
        }
      end
      remote_async :get_latest_sensor_value

      #
      # 指定されたセンサーの時系列データを取得する
      #
      # @param [String] id  センサーのID
      # @param [Integer] tm  データ取得を開始する時刻情報(UNIX時刻)
      # @param [Integer] span  データ取得を行う期間(秒)
      #
      # @return [Hash] 計測値を格納したHash
      #
      # @note
      #   本APIではtmからspanの間の時系列情報を取得する。tmに0を指定した
      #   場合は例外的に、最新のデータから過去に遡ってspanの期間分のデー
      #   タを取得します。
      #
      def get_time_series_data(df, id, tm, span)
        EM.defer {
          begin
            db = DBA.open
            df.resolve(db.get_time_series_data(id, tm, span))

          rescue => e
            df.reject(e)

          ensure
            db&.close
          end
        }
      end
      remote_async :get_time_series_data
    end
  end
end
