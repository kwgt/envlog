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
          db  = SQLite3::Database.new(DB_PATH.to_s)
          db.busy_handler {
            Log.error("db") {"databse access is conflict, retry"}
            sleep(0.1)
            true
          }

          ret = self.allocate
          ret.instance_variable_set(:@db, db)

          return ret
        end

        undef :new
      end

      def close
        @db.close
      end

      def get_sensor_list
        rows = @db.execute(<<~EOQ)
          select SENSOR_TABLE.id,
                 datetime(SENSOR_TABLE.ctime),
                 datetime(SENSOR_TABLE.mtime),
                 SENSOR_TABLE.descr,
                 SENSOR_TABLE.state,
                 DATA_TABLE.temp,
                 DATA_TABLE.humidity,
                 DATA_TABLE.`air-pres`,
                 DATA_TABLE.rssi,
                 DATA_TABLE.vbat,
                 DATA_TABLE.vbus
              from SENSOR_TABLE left join DATA_TABLE
                  on SENSOR_TABLE.id = DATA_TABLE.sensor and
                     SENSOR_TABLE.mtime = DATA_TABLE.time
              where addr is not NULL;
        EOQ

        ret = rows.inject([]) { |m, n|
          m << {
            :id    => n[0],
            :ctime => n[1],
            :mtime => n[2],
            :descr => n[3],
            :state => n[4],
            :temp  => n[5],
            :hum   => n[6],
            :"a/p" => n[7],
            :rssi  => n[8],
            :vbat  => n[9],
            :vbus  => n[10],
          }
        }

        return ret
      end

      def get_latest_value(id)
        row = @db.get_first_row(<<~EOQ, id)
          select state, mtime from SENSOR_TABLE where id = ?;
        EOQ

        if row[0] == "READY" || row[0] == "UNKNOWN" || row[0] == "PAUSE"
          ret = {
            :time  => row[1], 
            :state => row[0],
          }
        else
          stat = row[0]

          row  = @db.get_first_row(<<~EOQ, id)
            select time, temp, humidity, `air-pres`, rssi, vbat, vbus
                from DATA_TABLE where sensor = ? order by time desc limit 1;
          EOQ

          ret = {
            :time  => row[0],
            :temp  => row[1],
            :hum   => row[2],
            :"a/p" => row[3],
            :rssi  => row[4],
            :vbat  => row[5],
            :vbus  => row[6],
            :state => stat
          }
        end

        return ret
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

      def poll_sensor
        rows = @db.execute(<<~EOQ)
          select id, mtime from SENSOR_TABLE where addr is not NULL;
        EOQ

        return rows.inject({}) {|m, n| m[n[0]] = n[1]; m}
      end
    end
  end
end

