#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

#
# config.ymlのスキーマ定義によりどちらかしか設定できないことが前提
#

module EnvLog
  module Viewer
    class DBA
      class DeviceNotFound < StandardError; end
    end
  end
end

case
when EnvLog::Config.has?(:database, :sqlite3)
  require_relative "db/sqlite3"

when EnvLog::Config.has?(:database, :mysql)
  require_relative "db/mysql2"

else
  raise("really?")
end
