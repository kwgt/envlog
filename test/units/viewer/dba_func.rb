#! /usr/bin/env ruby
# coding: utf-8

require 'test/unit'
require 'yaml'
require 'json_schemer'

require_relative '../../lib/common'

require "#{PKG_LIB_DIR}/viewer/db"

Thread.abort_on_exception = true

class TestViewerDBAFunc < Test::Unit::TestCase
  SCHEMA_PATH = TEST_DATA_DIR + "schema" + "viewer" + "dba_func.yml"

  class << self
    def startup
      @@schema = YAML.load_file(SCHEMA_PATH)
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
    #pp sch.validate(data).to_a
    return sch.valid?(data)
  end

  #
  # poll_sensor()
  #
  test "call poll_sensor()" do
    res = @db.poll_sensor

    pp res if $DEBUG
    assert_true(check("RESULT(poll_sensor)", res))
  end
end
