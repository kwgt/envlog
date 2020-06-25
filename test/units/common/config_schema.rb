#! /usr/bin/env ruby
# coding: utf-8

require 'test/unit'
require 'yaml'
require 'json_schemer'

require_relative '../../lib/common'

class TestConfigSchema < Test::Unit::TestCase
  SCHEMA = YAML.load_file(PKG_DATA_DIR + "schema.yml")

  class << self
    def startup
    end

    def shutdown
    end
  end

  #
  # SQLite3設定の有効化
  #
  test "enable SQLite3" do
    config  = YAML.load_file(TEST_DATA_DIR + "config" + "sqlite3.yml")
    schemer = JSONSchemer.schema(SCHEMA["CONFIG"])
    diag    = schemer.validate(config).to_a

    assert_empty(diag)
  end

  #
  # MySQL設定の有効化
  #
  test "enable MySQL" do
    config  = YAML.load_file(TEST_DATA_DIR + "config" + "mysql.yml")
    schemer = JSONSchemer.schema(SCHEMA["CONFIG"])
    diag    = schemer.validate(config).to_a

    assert_empty(diag)
  end

  #
  # SQLite3, MySQL両設定の有効化
  #
  test "enable both SQLite3 and MySQL" do
    config  = YAML.load_file(TEST_DATA_DIR + "config" + "both_db.yml")
    schemer = JSONSchemer.schema(SCHEMA["CONFIG"])
    diag    = schemer.validate(config).to_a

    assert_not_empty(diag)
  end
end
