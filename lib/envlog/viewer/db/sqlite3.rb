#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'sqlite3'
require 'date'

module EnvLog
  module Viewer
    class DBA
      DB_PATH = Config.fetch_path(:database, :sqlite3, :path)

      class << self
        def open
          db  = SQLite3::Database.new(DB_PATH.to_s)
          db.busy_handler {
            Log.error("sqlite3") {"databse access is conflict, retry"}
            sleep(0.1)
            true
          }

          obj = self.allocate
          obj.instance_variable_set(:@db, db)

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
        rows = @db.execute(<<~EOQ)
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

        raise DeviceNotFound.new("device #{id} is not found") if not row

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
            select time, temp, humidity, `air-pres`
                from DATA_TABLE
                where sensor = ? and
                      time >= datetime(?, "-#{span} seconds");
          EOQ
        else
          rows = @db.execute2(<<~EOQ, id, tm)
            select datetime(time, 'localtime'),
                   temp, humidity, `air-pres`
                from DATA_TABLE
                where sensor = ? and
                    time >= ? and time <= datetime(?, "+#{span} seconds");
          EOQ
        end

        rows.shift

        row0 = rows.inject([]) {|m, n| m << n[0]}
        row1 = (rows.dig(0, 1))? (rows.inject([]) {|m, n| m << n[1]}): nil
        row2 = (rows.dig(0, 2))? (rows.inject([]) {|m, n| m << n[2]}): nil
        row3 = (rows.dig(0, 3))? (rows.inject([]) {|m, n| m << n[3]}): nil

        return {:time => row0, :temp => row1, :hum => row2, :"a/p" => row3}
      end

      def get_abstracted_hour_data(id, tm, span)
        date  = Date.parse(tm)
        head  = (date - (span - 1)).strftime("%Y-%m-%d")
        tail  = date.strftime("%Y-%m-%d")

        rows1 = @db.execute(<<~EOQ, id, head, tail)
          select strftime("%Y-%m-%d %H:00:00", time) as hour,
                 avg(temp), avg(humidity), avg(`air-pres`)
              from DATA_TABLE
              where sensor = ? and
                    (strftime("%Y-%m-%d", time) between ? and ?)
              group by hour order by hour;
        EOQ

        rows2 = @db.execute(<<~EOQ, id, head, tail)
          select strftime("%Y-%m-%d", time) as day,
                 min(temp), max(temp),
                 min(humidity), max(humidity),
                 min(`air-pres`), max(`air-pres`)
              from DATA_TABLE
              where sensor = ? and
                    (day between ? and ?)
              group by day order by day;
        EOQ

        time = rows1.inject([]) {|m, n| m << n[0]}
        date = rows2.inject([]) {|m, n| m << n[0]}

        if rows1.first and rows1.first[1]
          temp = {:min => [], :max => [], :avg => []}

          rows1.each { |row|
            temp[:avg] << row[1]
          }

          rows2.each { |row|
            temp[:min] << row[1]
            temp[:max] << row[2]
          }

        else
          temp = nil
        end

        if rows1.first and rows1.first[2]
          hum = {:min => [], :max => [], :avg => []}

          rows1.each { |row|
            hum[:avg] << row[2]
          }

          rows2.each { |row|
            hum[:min] << row[3]
            hum[:max] << row[4]
          }

        else
          hum = nil
        end

        if rows1.first and rows1.first[3]
          pres = {:min => [], :max => [], :avg => []}

          rows1.each { |row|
            pres[:avg] << row[3]
          }

          rows2.each { |row|
            pres[:min] << row[5]
            pres[:max] << row[6]
          }

        else
          pres = nil
        end

        ret = {
          :time  => time,
          :date  => date,
          :temp  => temp,
          :hum   => hum,
          :"a/p" => pres
        }

        return ret
      end

      def get_abstracted_day_data(id, tm, span)
        date = Date.parse(tm)
        head = (date - (span - 1)).strftime("%Y-%m-%d")
        tail = date.strftime("%Y-%m-%d")

        rows = @db.execute(<<~EOQ, id, head, tail)
          select strftime("%Y-%m-%d", time) as day,
                 min(temp), max(temp), avg(temp),
                 min(humidity), max(humidity), avg(humidity),
                 min(`air-pres`), max(`air-pres`), avg(`air-pres`)
              from DATA_TABLE where sensor = ? and (day between ? and ?)
              group by day order by day;
        EOQ

        time = rows.inject([]) {|m, n| m << n[0]}

        if rows.first and rows.first[1]
          temp = {:min => [], :max => [], :avg => []}
          rows.each { |row|
            temp[:min] << row[1]
            temp[:max] << row[2]
            temp[:avg] << row[3]
          }

        else
          temp = nil
        end

        if rows.first and rows.first[4]
          hum = {:min => [], :max => [], :avg => []}
          rows.each { |row|
            hum[:min] << row[4]
            hum[:max] << row[5]
            hum[:avg] << row[6]
          }

        else
          hum = nil
        end

        if rows.first and rows.first[7]
          pres = {:min => [], :max => [], :avg => []}
          rows.each { |row|
            pres[:min] << row[7]
            pres[:max] << row[8]
            pres[:avg] << row[9]
          }

        else
          pres = nil
        end

        return {:date => time, :temp => temp, :hum => hum, :"a/p" => pres}
      end


      def poll_sensor
        rows = @db.execute(<<~EOQ)
          select id, mtime from SENSOR_TABLE where addr is not NULL;
        EOQ

        return rows.inject({}) {|m, n| m[n[0]] = n[1]; m}
      end

      def get_sensor_info(id)
        row = @db.get_first_row(<<~EOQ, id)
          select addr, ctime, descr, `pow-source`, state
              from SENSOR_TABLE where id = ?;
        EOQ

        raise DeviceNotFound.new("device #{id} is not found") if not row

        ret = {
          :addr  => row[0],
          :ctime => row[1],
          :descr => row[2],
          :psrc  => row[3],
          :state => row[4],
        }

        return ret
      end
    end
  end
end

