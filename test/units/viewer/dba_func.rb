#! /usr/bin/env ruby
# coding: utf-8

require 'test/unit'
require 'yaml'
require 'json_schemer'

require_relative '../../lib/common'

require "#{LIB_DIR}/viewer/db"

Thread.abort_on_exception = true

class TestViewerDBAFunc < Test::Unit::TestCase
  using KeyConverter
  using YAMLExtender

  SCHEMA_PATH = TEST_DATA_DIR + "schema" + "viewer" + "dba_func.yml"

  class << self
    def startup
      @@schema = YAML.load_erb(SCHEMA_PATH)
    end

    def shutdown
    end
  end

  def setup
    @db = EnvLog::Viewer::DBA.open()
  end

  def teardown
    @db.close
  end

  def check(key, data)
    sch = JSONSchemer.schema(@@schema[key])
    #pp data
    #pp sch.validate(data.stringify_keys).to_a
    return sch.valid?(data.stringify_keys)
  end

  #
  # poll_sensor()
  #
  test "call poll_sensor()" do
    res = @db.poll_sensor
    assert_true(check("RESULT(poll_sensor)", res))
  end

  #
  # get_sensor_info()
  #
  test "call get_sensor_info()" do
    #
    # normal test
    #
    ids = @db.poll_sensor.keys 

    ids.each { |id|
      info = assert_nothing_raised {@db.get_sensor_info(id)}
      assert_true(check("RESULT(get_sensor_info)", info))
    }

    #
    # error test
    #
    assert_raise_kind_of(EnvLog::Viewer::DBA::DeviceNotFound) {
      @db.get_sensor_info("000000000000");
    }
  end

  #
  # get_abstracted_hour_data()
  #
  test "call get_abstracted_hour_data()" do
    ids = @db.poll_sensor.keys
    ids.each { |id|
      info = assert_nothing_raised {
        @db.get_abstracted_hour_data(id, "2020-08-11", 7)
      }
      assert_true(check("RESULT(get_abstracted_hour_data)", info))
    }
  end

  #
  # get_abstracted_day_data()
  #
  test "call get_abstracted_day_data()" do
    ids = @db.poll_sensor.keys
    ids.each { |id|
      info = assert_nothing_raised {
        @db.get_abstracted_day_data(id, "2020-08-11", 7)
      }
      assert_true(check("RESULT(get_abstracted_day_data)", info))
    }
  end
end
