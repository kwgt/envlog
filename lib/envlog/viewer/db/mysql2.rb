#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'mysql2'
require "#{LIB_DIR}/mysql2"

module EnvLog
  module Viewer
    class DBA
      DB_CRED = Config.dig(:database, :mysql)

      using Mysql2Extender

      class << self
        def open
          ret = self.allocate
          ret.instance_variable_set(:@db, Mysql2::Client.new(DB_CRED))

          return ret
        end

        undef :new
      end

      def close
        @db.close
      end

      def get_sensor_list
        rows = @db.query(<<~EOQ, :as => :array)
          select id, ctime, mtime, descr, state
              from SENSOR_TABLE addr is not NULL;
        EOQ

        ret = rows.inject([]) { |m, n|
          m << {
            :id    => n[0],
            :ctime => n[1],
            :mtime => n[2],
            :descr => n[3],
            :state => n[4]
          }
        }

        return ret
      end

      def get_sensor_value(id)
        row = @db.get_first_row(<<~EOQ, :as => :array)
          select temp, humidity, `air-pres`
              from DATA_TABLE where sensor = "#{id}"
              order by time desc limit 1;
        EOQ

        return {:temp => row[0], :hum => row[1], :"a/p" => row[2]}
      end

      def get_time_series_data(id, tm, span)
        if tm.zero?
          rows = @db.query(<<~EOQ, :as => :array)
            select time, temp, humidity, `air-pres` from DATA_TABLE
                where sensor = "#{id}" and
                      time >= (NOW() - interval #{span} second);
          EOQ
        else
          rows = @db.query(<<~EOQ, :as => :array)
            select time, temp, humidity, `air-pres` from DATA_TABLE
                where sensor = "#{id}" and
                      time >= "#{tm}" and
                      time <= (#{tm} + interval #{span} seconds);
          EOQ
        end

        ret = {:time => [], :temp => [], :hum => [], :"a/p" => []}

        rows.each { |row|
          ret[:time]  << row[0]
          ret[:temp]  << row[1]
          ret[:hum]   << row[2]
          ret[:"a/p"] << row[3]
        }

        return ret
      end
    end
  end
end
