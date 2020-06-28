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
  module Logger
    module DBA
      DB_CRED = Config.dig(:database, :mysql)

      class << self
        using Mysql2Extender

        def get_alives
          db   = Mysql2::Client.new(DB_CRED)

          rows = db.query(<<~EOQ, :as => :array)
            select addr, id from SENSOR_TABLE where addr is not NULL;
          EOQ

          return rows.inject([]) {|m, n| m << {:addr => n[0], :id => n[1]}}

        ensure
          db&.close
        end

        def get_sensor_info(addr)
          db  = Mysql2::Client.new(DB_CRED)

          row = db.get_first_row(<<~EOQ, :as => :array)
            select id, `pow-source`, state
                from SENSOR_TABLE where addr = "#{addr}";
          EOQ

          if row
            ret = {
              :id     => row[0],
              :powsrc => row[1],
              :state  => row[2],
            }

          else
            ret = nil
          end

          return ret

        ensure
          db&.close
        end

        def poll_sensor
          db = Mysql2::Client.new(DB_CRED)

          rows = db.query(<<~EOQ, :as => :array)
            select id, mtime from SENSOR_TABLE where addr is not NULL;
          EOQ

          ret = rows.inject({}) { |m, n|
            m[n[0]] = {:mtime => n[1].to_s, :state => n[2]}; m
          }

          return ret

        ensure
          db&.close
        end

        def put_data(d, s)
          db = Mysql2::Client.new(DB_CRED)

          db.query("start transaction;")

          id = db.get_first_value(<<~EOQ)
            select id from SENSOR_TABLE where addr = "#{d["addr"]}";
          EOQ

          raise(NotRegisterd) if not id

          seq = db.get_first_value(<<~EOQ)
            select `last-seq` from SENSOR_TABLE where id = "#{id}";
          EOQ

          raise(NotUpdated) if d["seq"] == seq

          now = Time.now.strftime("%Y-%m-%d %H:%m%s")

          db.query(<<~EOQ)
            insert into DATA_TABLE
                values ("#{id}",
                        "#{now}",
                        #{d["temp"]},
                        #{d["hum"]},
                        #{d["a/p"]},
                        #{d["rssi"]},
                        #{d["vbat"]},
                        #{d["vbus"]});
          EOQ

          db.query(<<~EOQ)
            update SENSOR_TABLE
                set `last-seq` = #{d["seq"]},
                    mtime = "#{now}",
                    state = "#{s}"
                where id = "#{id}";
          EOQ

          db.query("commit;")

        rescue NotUpdated
          db.query("rollback;")

        rescue NotRegisterd
          Log.error("db") {
            "unregister sensor requested (#{d["addr"]})"
          }
          db.query("rollback;")

        rescue => e
          db.query("rollback;")
          raise(e)

        ensure
          db&.close
        end

        def set_stall(id)
          db = Mysql2::Client.new(DB_CRED)

          db.query("start transaction;")

          db.query(<<~EOQ)
            update SENSOR_TABLE
                set mtime = datetime('now', 'localtime'),
                    state = "STALL"
                where id = "#{id}";
          EOQ

          db.query("commit;")

        rescue => e
          db.query("rollback;")
          raise(e)

        ensure
          db&.close
        end
      end
    end
  end
end
