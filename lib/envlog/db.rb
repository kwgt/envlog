#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

module EnvLog
  module Database
    class DeviceBusy < StandardError; end
    class DeviceNotFound < StandardError; end

    class << self
      def valid_power_source?(src)
        return %w[STABLE BATTERY NONE].include?(src.upcase)
      end

      def recording_state?(st)
        return %w[NORMAL DEAD-BATTERY].include?(st.upcase)
      end

      def pause_state?(st)
        return st.upcase == "PAUSE"
      end
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
