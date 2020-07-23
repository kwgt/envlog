#! /usr/bin/env ruby
# coding: utf-8

require 'test/unit'
require 'yaml'
require 'json_schemer'

require_relative '../../lib/common'

require "#{LIB_DIR}/db"
require "#{LIB_DIR}/logger/db"

Thread.abort_on_exception = true

class TestLoggerDBAFunc < Test::Unit::TestCase
  using KeyConverter
  using YAMLExtender
  using TimeStringFormatChanger

  SCHEMA_PATH = TEST_DATA_DIR + "schema" + "logger" + "dba_func.yml"

  class << self
    def startup
      @@schema = YAML.load_erb(SCHEMA_PATH)
    end

    def shutdown
    end
  end

  def setup
    @dba = EnvLog::Logger::DBA
  end

  def teardown
  end

  def check(key, data)
    sch = JSONSchemer.schema(@@schema[key])
    #pp data
    #pp sch.validate(data).to_a
    return sch.valid?(data.stringify_keys)
  end

  def add_dummy_device(state)
    @addr =  (Array.new(6) {"%02x" % rand(255)}).join(":")
    EnvLog::Database.add_dummy_device(@addr, state)

    info = @dba.get_sensor_info(@addr)

    return info[:id]
  end

  def remove_dummy_device
    EnvLog::Database.remove_device(@addr)
  end

  test "method implementation" do
    assert_respond_to(@dba, :get_alives)
    assert_respond_to(@dba, :get_sensor_info)
    assert_respond_to(@dba, :poll_sensor)
    assert_respond_to(@dba, :put_data)
    assert_respond_to(@dba, :set_stall)
    assert_respond_to(@dba, :update_timestamp)
    assert_respond_to(@dba, :regist_unknown)
  end

  #
  # get_alives()
  #
  test "call get_alives()" do
    res = @dba.get_alives()
    assert_true(check("RESULT(get_alives)", res))
  end

  #
  # get_sensor_info()
  #
  test "call get_sensor_info()" do
    alives = @dba.get_alives()
    alives.each { |info|
      res = @dba.get_sensor_info(info[:addr])
      assert_true(check("RESULT(get_sensor_info)", res))
    }

    # 存在しないデバイスアドレスを指定した場合
    res = @dba.get_sensor_info("00:00:00:00:00:00")
    assert_nil(res)
  end

  #
  # poll_sensor()
  #
  test "call poll_sensor()" do
    res = @dba.poll_sensor()
    assert_true(check("RESULT(poll_sensor)", res))
  end

  #
  # put_data
  #
  test "call put_data()" do
    pend if /-dev$/ !~ ENV["CONFIG"]

    id  = add_dummy_device(:NORMAL)
    seq = 0
    now = Time.now

    #
    # 通常データ 
    #
    data = {
      "addr" => @addr,
      "seq"  => seq,
      "temp" => 24.5,
      "hum"  => 50.0,
      "a/p"  => 1001,
      "rssi" => -70,
      "vbat" => 5.0,
      "vbus" => 5.0,
    }

    assert_nothing_raised {
      @dba.put_data(id, now.to_s, data, "NORMAL")
    }

    #
    # 欠損(1)
    #
    seq += 1
    now += 1
    data = {
      "addr" => @addr,
      "seq"  => seq,
      "temp" => 24.5,
      "hum"  => 50.0,
      "a/p"  => 1001,
    }

    assert_nothing_raised {
      @dba.put_data(id, now.to_s, data, "NORMAL")
    }

    #
    # 欠損(2)
    #
    seq += 1
    now += 1
    data = {
      "addr" => @addr,
      "seq"  => seq,
      "temp" => 24.5,
      "hum"  => 50.0,
    }

    assert_nothing_raised {
      @dba.put_data(id, now.to_s, data, "NORMAL")
    }

  ensure
    #remove_dummy_device()

  end
end
