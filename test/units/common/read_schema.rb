#! /usr/bin/env ruby
# coding: utf-8

require 'test/unit'
require 'yaml'
require 'json_schemer'

require_relative '../../lib/common'

class TestReadSchema < Test::Unit::TestCase
  class << self
    def startup
    end

    def shutdown
    end
  end

  #
  # スキーマデータの読み出し
  #
  test "read configuration" do
    assert_nothing_raised {
      EnvLog::Schema.read(PKG_DATA_DIR + "schema.yml")
    }

    assert_not_nil(EnvLog::Schema[:CONFIG])
    assert_not_nil(EnvLog::Schema[:INPUT_DATA])
  end
end
