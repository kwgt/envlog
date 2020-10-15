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
                 DATA_TABLE_V2.temp,
                 DATA_TABLE_V2.`r/h`,
                 DATA_TABLE_V2.`v/h`,
                 DATA_TABLE_V2.`a/p`,
                 DATA_TABLE_V2.rssi,
                 DATA_TABLE_V2.vbat,
                 DATA_TABLE_V2.vbus
              from SENSOR_TABLE left join DATA_TABLE_V2
                  on SENSOR_TABLE.id = DATA_TABLE_V2.sensor and
                     SENSOR_TABLE.mtime = DATA_TABLE_V2.time
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
            :"r/h" => n[6],
            :"v/h" => n[7],
            :"a/p" => n[8],
            :rssi  => n[9],
            :vbat  => n[10],
            :vbus  => n[11],
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
            select time, temp, `r/h`, `v/h`, `a/p`, rssi, vbat, vbus
                from DATA_TABLE_V2 where sensor = ? order by time desc limit 1;
          EOQ

          ret = {
            :time  => row[0],
            :temp  => row[1],
            :"r/h" => row[2],
            :"v/h" => row[3],
            :"a/p" => row[4],
            :rssi  => row[5],
            :vbat  => row[6],
            :vbus  => row[7],
            :state => stat
          }
        end

        return ret
      end

      def get_time_series_data(id, tm, span)
        if tm == "now"
          rows = @db.execute2(<<~EOQ, id, "now")
            select time, temp, `r/h, `v/h, `a/p`
                from DATA_TABLE_V2
                where sensor = ? and
                      time >= datetime(?, "-#{span} seconds");
          EOQ

        else
          rows = @db.execute2(<<~EOQ, id, tm, tm)
            select time, temp, `r/h`, `v/h`, `a/p`
                from DATA_TABLE_V2
                where sensor = ? and
                    time <= ? and time >= datetime(?, "-#{span} seconds");
          EOQ
        end

        rows.shift

        row0 = rows.inject([]) {|m, n| m << n[0]}
        row1 = (rows.dig(0, 1))? (rows.inject([]) {|m, n| m << n[1]}): nil
        row2 = (rows.dig(0, 2))? (rows.inject([]) {|m, n| m << n[2]}): nil
        row3 = (rows.dig(0, 3))? (rows.inject([]) {|m, n| m << n[3]}): nil
        row4 = (rows.dig(0, 4))? (rows.inject([]) {|m, n| m << n[4]}): nil

        ret = {
          :time  => row0,
          :temp  => row1,
          :"r/h" => row2,
          :"v/h" => row3,
          :"a/p" => row4
        }

        return ret
      end

      def get_raw_data(id, tm, span)
        date  = Date.parse(tm)
        head  = (date - (span - 1)).strftime("%Y-%m-%d")
        tail  = date.strftime("%Y-%m-%d")

        rows = @db.execute2(<<~EOQ, id, head, tail)
          select time, temp, `r/h`, `v/h`, `a/p`
              from DATA_TABLE_V2
              where sensor = ? and (date(time) between ? and ?);
        EOQ

        rows.shift

        row0 = rows.inject([]) {|m, n| m << n[0]}
        row1 = (rows.dig(0, 1))? (rows.inject([]) {|m, n| m << n[1]}): nil
        row2 = (rows.dig(0, 2))? (rows.inject([]) {|m, n| m << n[2]}): nil
        row3 = (rows.dig(0, 3))? (rows.inject([]) {|m, n| m << n[3]}): nil
        row4 = (rows.dig(0, 4))? (rows.inject([]) {|m, n| m << n[4]}): nil

        ret = {
          :time  => row0,
          :temp  => row1,
          :"r/h" => row2,
          :"v/h" => row3,
          :"a/p" => row4
        }

        return ret
      end

      def get_abstracted_hour_data(id, tm, span)
        date  = Date.parse(tm)
        head  = (date - (span - 1)).strftime("%Y-%m-%d")
        tail  = date.strftime("%Y-%m-%d")

        rows1 = @db.execute(<<~EOQ, id, head, tail)
          select strftime("%Y-%m-%d %H:00:00", time) as hour,
                 avg(temp), avg(`r/h`), avg(`v/h`), avg(`a/p`)
              from DATA_TABLE_V2
              where sensor = ? and
                    (strftime("%Y-%m-%d", time) between ? and ?)
              group by hour order by hour;
        EOQ

        rows2 = @db.execute(<<~EOQ, id, head, tail)
          select strftime("%Y-%m-%d", time) as day,
                 min(temp),  max(temp),
                 min(`r/h`), max(`r/h`),
                 min(`v/h`), max(`v/h`),
                 min(`a/p`), max(`a/p`)
              from DATA_TABLE_V2
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
          rh = {:min => [], :max => [], :avg => []}

          rows1.each { |row|
            rh[:avg] << row[2]
          }

          rows2.each { |row|
            rh[:min] << row[3]
            rh[:max] << row[4]
          }

        else
          rh = nil
        end

        if rows1.first and rows1.first[3]
          vh = {:min => [], :max => [], :avg => []}

          rows1.each { |row|
            vh[:avg] << row[3]
          }

          rows2.each { |row|
            vh[:min] << row[5]
            vh[:max] << row[6]
          }

        else
          vh = nil
        end

        if rows1.first and rows1.first[4]
          ap = {:min => [], :max => [], :avg => []}

          rows1.each { |row|
            ap[:avg] << row[4]
          }

          rows2.each { |row|
            ap[:min] << row[7]
            ap[:max] << row[8]
          }

        else
          ap = nil
        end

        ret = {
          :time  => time,
          :date  => date,
          :temp  => temp,
          :"r/h" => rh,
          :"v/h" => vh,
          :"a/p" => ap
        }

        return ret
      end

      def get_abstracted_day_data(id, tm, span)
        date = Date.parse(tm)
        head = (date - (span - 1)).strftime("%Y-%m-%d")
        tail = date.strftime("%Y-%m-%d")

        rows = @db.execute(<<~EOQ, id, head, tail)
          select strftime("%Y-%m-%d", time) as day,
                 min(temp),  max(temp),  avg(temp),
                 min("r/h"), max("r/h"), avg("r/h"),
                 min("v/h"), max("v/h"), avg("v/h"),
                 min(`a/p`), max(`a/p`), avg(`a/p`)
              from DATA_TABLE_V2 where sensor = ? and (day between ? and ?)
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
          rh = {:min => [], :max => [], :avg => []}
          rows.each { |row|
            rh[:min] << row[4]
            rh[:max] << row[5]
            rh[:avg] << row[6]
          }

        else
          rh = nil
        end

        if rows.first and rows.first[7]
          vh = {:min => [], :max => [], :avg => []}
          rows.each { |row|
            vh[:min] << row[7]
            vh[:max] << row[8]
            vh[:avg] << row[9]
          }

        else
          vh = nil
        end

        if rows.first and rows.first[10]
          ap = {:min => [], :max => [], :avg => []}
          rows.each { |row|
            ap[:min] << row[10]
            ap[:max] << row[11]
            ap[:avg] << row[12]
          }

        else
          ap = nil
        end

        ret = {
          :date  => time,
          :temp  => temp,
          :"r/h" => rh,
          :"v/h" => vh,
          :"a/p" => ap
        }

        return ret
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

