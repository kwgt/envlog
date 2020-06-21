#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'sqlite3'

module EnvLog
  module Viewer
    class DBA
      DB_PATH = Config.fetch_path(:database, :sqlite3, :path)

      class << self
        def open
          ret = self.allocate
          ret.instance_variable_set(:@db, SQLite3::Database.new(DB_PATH.to_s))

          return ret
        end

        undef :new
      end

      def close
        @db.close
      end

      def get_sensor_list
        rows = @db.execute(<<~EOQ)
          select id, datetime(ctime), datetime(mtime), descr, state
              from SENSOR_TABLE where addr is not NULL;
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
        row = @db.get_first_row(<<~EOQ, id)
          select temp, humidity, `air-pres`
              from DATA_TABLE where sensor = ? order by time desc limit 1;
        EOQ

        return {:temp => row[0], :hum => row[1], :"a/p" => row[2]}
      end

      def get_time_series_data(id, tm, span)
        if tm.zero?
          rows = @db.execute2(<<~EOQ, id, "now")
            select time, temp, humidity, `air-pres` from DATA_TABLE
                where sensor = ? and
                      time >= datetime(?, "localtime", "-#{span} seconds");
          EOQ
        else
          rows = @db.execute2(<<~EOQ, id, tm, tm)
            select time, temp, humidity, `air-pres` from DATA_TABLE
                where sensor = ? and
                    time >= datetime(?, "localtime") and
                    time <= datetime(?, "localtime", "+#{span} seconds");
          EOQ
        end

        ret = {:time => [], :temp => [], :hum => [], :"a/p" => []}

        rows.shift
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

