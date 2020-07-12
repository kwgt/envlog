#! /usr/bin/env ruby
# coding: utf-8

if not ENV.include?("CONFIG")
  ENV["CONFIG"] = "sqlite3-dev"

elsif /-dev$/ !~ ENV["CONFIG"]
  raise("please use dev config file")
end

require 'test/unit'
require 'yaml'
require 'json_schemer'

require_relative '../../lib/common'

require "#{LIB_DIR}/db"

Thread.abort_on_exception = true

class TestCommonDatabaseFunc < Test::Unit::TestCase
  using KeyConverter
  using YAMLExtender

  ID_REGEXP = /^\h{8}-\h{4}-4\h{3}-\h{4}-\h{12}$/

  class << self
    def startup
    end

    def shutdown
    end
  end

  def setup
    @db = EnvLog::Database
  end

  def teardown
  end

  def new_addr
    return (Array.new(6) {"%02x" % rand(255)}).join(":") 
  end

  #
  # method implementation
  #
  test "method implementation" do
    # for test use
    assert_respond_to(@db, :clear_sensor_table)
    assert_respond_to(@db, :add_dummy_device)
    assert_respond_to(@db, :get_device_info)

    # for actual implementation
    assert_respond_to(@db, :list_device)
    assert_respond_to(@db, :add_device)
    assert_respond_to(@db, :set_description)
    assert_respond_to(@db, :set_power_source)
    assert_respond_to(@db, :activate)
    assert_respond_to(@db, :pause)
    assert_respond_to(@db, :resume)
  end

  #
  # add_device()
  #
  test "add_device()" do
    @db.clear_sensor_table

    addr = new_addr()

    #
    # 初登録
    #
    assert_nothing_raised {
      @db.add_device(addr, "TEST", "STABLE")
    }

    a = @db.list_device()
    assert_equal(1, a.size)
    assert_match(ID_REGEXP, a.dig(0, :id))
    assert_equal(addr, a.dig(0, :addr))
    assert_equal("READY", a.dig(0, :state))
    assert_equal("TEST", a.dig(0, :descr))

    #
    # 二重登録
    #
    assert_raise_kind_of(EnvLog::Database::DeviceBusy) {
      @db.add_device(addr, "TEST", "STABLE")
    }

    #
    # UNKNOWNからの登録
    # T.B.D
  end

  #
  # list_device()
  #
  test "list_device()" do
    @db.clear_sensor_table

    addr1 = new_addr()
    addr2 = new_addr()
    addr3 = new_addr()

    a = assert_nothing_raised {@db.list_device()}
    assert_empty(a)

    @db.add_device(addr1, "#1", "STABLE")

    a = assert_nothing_raised {@db.list_device()}
    assert_equal(1, a.size)

    @db.add_device(addr2, "#2", "BATTERY")

    a = assert_nothing_raised {@db.list_device()}
    assert_equal(2, a.size)

    @db.add_device(addr3, "#3", "NONE")

    a = assert_nothing_raised {@db.list_device()}
    assert_equal(3, a.size)
  end

  #
  # set_description()
  #
  test "set_description()" do
    @db.clear_sensor_table

    #
    # 通常の設定変更
    #
    addr = new_addr()
    @db.add_device(addr, "#1", "STABLE")

    assert_nothing_raised {@db.set_description(addr, "TEST")}

    info = @db.get_device_info(addr)

    assert_equal("TEST", info[:descr])

    #
    # 存在しないデバイスへの設定変更
    #
    assert_raise_kind_of(EnvLog::Database::DeviceNotFound) {
      @db.set_description(new_addr(), "TEST")
    }
  end

  #
  # set_power_source()
  #
  test "set_power_source()" do
    @db.clear_sensor_table

    addr = new_addr()
    @db.add_device(addr, "#1", "STABLE")

    #
    # 通常の設定変更
    #
    assert_nothing_raised {@db.set_power_source(addr, "STABLE")}
    info = @db.get_device_info(addr)
    assert_equal("STABLE", info[:psrc])

    assert_nothing_raised {@db.set_power_source(addr, "BATTERY")}
    info = @db.get_device_info(addr)
    assert_equal("BATTERY", info[:psrc])

    assert_nothing_raised {@db.set_power_source(addr, "NONE")}
    info = @db.get_device_info(addr)
    assert_equal("NONE", info[:psrc])

    #
    # 受け付けられないパワーソースの指定
    #
    assert_raise_kind_of(ArgumentError) {
      @db.set_power_source(addr, "AAA")
    }

    #
    # 存在しないデバイスへの設定変更
    #
    assert_raise_kind_of(EnvLog::Database::DeviceNotFound) {
      @db.set_power_source(new_addr(), "STABLE")
    }
  end

  #
  # activate()
  #
  test "activate()" do
    @db.clear_sensor_table

    #
    # 通常のアクティベート
    #
    addr = new_addr()
    @db.add_dummy_device(addr, :UNKNOWN)
    @db.set_power_source(addr, "STABLE")
    orig = @db.get_device_info(addr)

    assert_nothing_raised {@db.activate(addr)}
    info = @db.get_device_info(addr)
    assert_equal(orig[:id],    info[:id])
    assert_equal(orig[:addr],  info[:addr])
    assert_equal("READY",      info[:state])
    assert_equal(orig[:psrc],  info[:psrc])
    assert_equal(orig[:descr], info[:descr])

    assert_not_equal(orig[:state], info[:state])

    #
    # UNKNOWN以外のデバイスのアクティベート
    #
    assert_raise_kind_of(RuntimeError) {
      @db.activate(addr)
    }

    #
    # パワーソース未設定状態でのアクティベート
    #
    addr = new_addr()
    @db.add_dummy_device(addr, :UNKNOWN)

    assert_raise_kind_of(RuntimeError) {
      @db.activate(addr)
    }

    #
    # 存在しないデバイスのアクティベート
    #
    assert_raise_kind_of(EnvLog::Database::DeviceNotFound) {
      @db.activate(new_addr())
    }
  end

  test "pause()" do
    @db.clear_sensor_table

    #
    # 通常のポーズ (NORMAL)
    #
    addr = new_addr()
    @db.add_dummy_device(addr, "NORMAL")
    orig = @db.get_device_info(addr)

    assert_nothing_raised {@db.pause(addr)}
    info = @db.get_device_info(addr)
    assert_equal(orig[:id],    info[:id])
    assert_equal(orig[:addr],  info[:addr])
    assert_equal("PAUSE",      info[:state])
    assert_equal(orig[:psrc],  info[:psrc])
    assert_equal(orig[:descr], info[:descr])

    assert_not_equal(orig[:state], info[:state])

    #
    # 通常のポーズ (DEAD-BATTRY)
    #
    addr = new_addr()
    @db.add_dummy_device(addr, "DEAD-BATTERY")
    orig = @db.get_device_info(addr)

    assert_nothing_raised {@db.pause(addr)}
    info = @db.get_device_info(addr)
    assert_equal(orig[:id],    info[:id])
    assert_equal(orig[:addr],  info[:addr])
    assert_equal("PAUSE",      info[:state])
    assert_equal(orig[:psrc],  info[:psrc])
    assert_equal(orig[:descr], info[:descr])

    assert_not_equal(orig[:state], info[:state])

    #
    # NORMAL,DEAD-BATTERY以外のデバイスのアクティベート
    #
    assert_raise_kind_of(RuntimeError) {
      @db.pause(addr)
    }

    #
    # 存在しないデバイスのアクティベート
    #
    assert_raise_kind_of(EnvLog::Database::DeviceNotFound) {
      @db.pause(new_addr())
    }
  end

  test "resume()" do
    @db.clear_sensor_table

    #
    # 通常のレジューム
    #
    addr = new_addr()
    @db.add_dummy_device(addr, "PAUSE")
    orig = @db.get_device_info(addr)

    assert_nothing_raised {@db.resume(addr)}
    info = @db.get_device_info(addr)
    assert_equal(orig[:id],    info[:id])
    assert_equal(orig[:addr],  info[:addr])
    assert_equal("NORMAL",     info[:state])
    assert_equal(orig[:psrc],  info[:psrc])
    assert_equal(orig[:descr], info[:descr])

    assert_not_equal(orig[:state], info[:state])

    #
    # PAUSE以外のデバイスのアクティベート
    #
    assert_raise_kind_of(RuntimeError) {
      @db.resume(addr)
    }

    #
    # 存在しないデバイスのアクティベート
    #
    assert_raise_kind_of(EnvLog::Database::DeviceNotFound) {
      @db.resume(new_addr())
    }
  end
end
