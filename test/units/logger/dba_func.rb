#! /usr/bin/env ruby
# coding: utf-8

require 'test/unit'
require 'yaml'
require 'json_schemer'

require_relative '../../lib/common'

require "#{LIB_DIR}/logger/db"

Thread.abort_on_exception = true

class TestLoggerDBAFunc < Test::Unit::TestCase
  using KeyConverter
  using YAMLExtender

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

  test "method implementation" do
    assert_respond_to(@dba, :get_alives)
    assert_respond_to(@dba, :get_sensor_info)
    assert_respond_to(@dba, :poll_sensor)
    assert_respond_to(@dba, :put_data)
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
end
