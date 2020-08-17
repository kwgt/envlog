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
      using Mysql2Extender
      using TimeStringFormatChanger

      DB_CRED = Config.dig(:database, :mysql)

      class << self
        def open
          obj = self.allocate
          obj.instance_variable_set(:@db, Mysql2::Client.new(DB_CRED))

          if block_given?
            begin
              ret = yield(obj)
            ensure
              obj.close
            end

          else
            ret = obj
          end

          return ret
        end

        undef :new
      end

      def close
        @db.close
      end

      def get_sensor_list
        rows = @db.query(<<~EOQ, :as => :array)
          select SENSOR_TABLE.id,
                 SENSOR_TABLE.ctime,
                 SENSOR_TABLE.mtime,
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
            :ctime => n[1].to_s,
            :mtime => n[2].to_s,
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
        row = @db.get_first_row(<<~EOQ, :as => :array)
          select state, mtime from SENSOR_TABLE where id = "#{id}";
        EOQ

        raise DeviceNotFound.new("device #{id} is not found") if not row

        if row[0] == "READY" || row[0] == "UNKNOWN" || row[0] == "PAUSE"
          ret  = {
            :time  => row[1].to_s,
            :state => row[0]
          }

        else
          stat = row[0]

          row = @db.get_first_row(<<~EOQ, :as => :array)
            select time, temp, humidity, `air-pres`, rssi, vbat, vbus
                from DATA_TABLE
                where sensor = "#{id}" order by time desc limit 1;
          EOQ

          ret = {
            :time  => row[0].to_s,
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

        row0 = rows.inject([]) {|m, n| m << n[0].to_s}
        row1 = (rows.first[1])? (rows.inject([]) {|m, n| m << n[1]}): nil
        row2 = (rows.first[2])? (rows.inject([]) {|m, n| m << n[2]}): nil
        row3 = (rows.first[3])? (rows.inject([]) {|m, n| m << n[3]}): nil

        return {:time => row0, :temp => row1, :hum => row2, :"a/p" => row3}
      end

      def poll_sensor
        rows = @db.query(<<~EOQ, :as => :array)
          select id, mtime from SENSOR_TABLE where addr is not NULL;
        EOQ

        return rows.inject({}) {|m, n| m[n[0]] = n[1].to_s; m}
      end

      def get_sensor_info(id)
        row = @db.get_first_row(<<~EOQ, :as => :array)
          select addr, ctime, descr, `pow-source`, state
              from SENSOR_TABLE where id = "#{id}";
        EOQ

        raise DeviceNotFound.new("device #{id} is not found") if not row

        ret = {
          :addr  => row[0],
          :ctime => row[1].to_s,
          :descr => row[2],
          :psrc  => row[3],
          :state => row[4],
        }

        return ret
      end
    end
  end
end
