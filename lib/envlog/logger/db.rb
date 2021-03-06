#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require "#{LIB_DIR + "db"}"

module EnvLog
  module Logger
    module DBA
      class NotRegisterd < StandardError; end
      class NotUpdated < StandardError; end
    end
  end
end

#
# config.ymlのスキーマ定義によりどちらかしか設定できないことが前提
#

case
when EnvLog::Config.has?(:database, :sqlite3)
  require_relative "db/sqlite3"

when EnvLog::Config.has?(:database, :mysql)
  require_relative "db/mysql2"

else
  raise("really?")
end

