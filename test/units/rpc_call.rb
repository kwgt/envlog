#! /usr/bin/env ruby
# coding: utf-8

require 'test/unit'
require 'yaml'
require 'json_schemer'

require_relative '../lib/common'
require_relative '../lib/rpc_client'

require "#{PKG_LIB_DIR}/misc"
require "#{PKG_LIB_DIR}/schema"
require "#{PKG_LIB_DIR}/config"
require "#{PKG_LIB_DIR}/viewer/websock"

Thread.abort_on_exception = true

class TestRpcProcedure < Test::Unit::TestCase
  class << self
    def startup
    end

    def shutdown
    end
  end

  #
  # RPCサーバへの接続
  #
  test "connect to RPC server" do
    EnvLog::Schema.read(DEFAULT_SCHEMA)
    EnvLog::Config.read(DEFAULT_CONFIG)

    EnvLog::Viewer::WebSocket.start(EnvLog::Viewer)

    Thread.fork {EM.run}

    sleep(1)

    port = RpcClient.new("ws://127.0.0.1:2565")
    port.connect

    res = port.call(:hello)
    assert_equal("OK", res)

    port.close

  ensure
    EM.stop
  end
end
