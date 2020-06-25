#! /usr/bin/env ruby
# coding: utf-8

require 'test/unit'
require 'yaml'
require 'json_schemer'

require_relative '../../lib/common'
require_relative '../../lib/rpc_client'

require "#{PKG_LIB_DIR}/viewer/db"
require "#{PKG_LIB_DIR}/viewer/websock"

Thread.abort_on_exception = true

class TestRpcProcedure < Test::Unit::TestCase
  SCHEMA_PATH = TEST_DATA_DIR + "schema" + "viewer" + "rpc_proc.yml"

  class << self
    def startup
      EnvLog::Viewer::WebSocket.start(EnvLog::Viewer)
      Thread.fork {EM.run}
      sleep(1)

      @@schema = YAML.load_file(SCHEMA_PATH)
    end

    def shutdown
      EM.stop
    end
  end

  def setup
    @port = RpcClient.new("ws://127.0.0.1:2565")
    @port.connect
  end

  def teardown
    @port.close
  end

  def check(key, data)
    sch = JSONSchemer.schema(@@schema[key])
    #pp data
    #pp sch.validate(data).to_a
    return sch.valid?(data)
  end

  #
  # RPCサーバへの接続
  #
  test "connect to RPC server" do
    res = @port.call(:hello)
    assert_equal("OK", res)
  end

  #
  # get_sensor_list()
  #
  test "call get_sensor_list()" do
    res = @port.call(:get_sensor_list)

    pp res if $DEBUG
    assert_true(check("RESULT(get_sensor_list)", res))
  end

  #
  # get_latest_sensor_value()
  #
  test "call get_latest_sensor_value()" do
    res = @port.call(:get_sensor_list)
    res = @port.call(:get_latest_sensor_value, res.dig(0, "id"))

    pp res if $DEBUG
    assert_true(check("RESULT(get_latest_sensor_value)", res))
  end
end
