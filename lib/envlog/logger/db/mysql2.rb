#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'mysql2'
require 'securerandom'
require "#{LIB_DIR}/mysql2"

module EnvLog
  module Logger
    module DBA
      DB_CRED = Config.dig(:database, :mysql)

      class << self
        using Mysql2Extender
        using TimeStringFormatChanger

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

        def put_data(id, ts, data, state)
          Log.debug("mysql2") {
            "put_data(#{id[0,8]}, #{ts}, #{data["seq"]})"
          }

          db = Mysql2::Client.new(DB_CRED)

          db.query("start transaction;")

          seq = db.get_first_value(<<~EOQ)
            select `last-seq` from SENSOR_TABLE where id = "#{id}";
          EOQ

          raise(NotUpdated) if data["seq"] == seq

          Log.debug("mysql2") {"insert #{ts}.#{id}"}

          db.query(<<~EOQ)
            insert into DATA_TABLE
                values ("#{id}",
                        "#{ts}",
                        #{data["temp"]},
                        #{data["hum"]},
                        #{data["a/p"]},
                        #{data["rssi"]},
                        #{data["vbat"]},
                        #{data["vbus"]});
          EOQ

          Log.debug("mysql2") {"update #{ts}.#{id}"}

          db.query(<<~EOQ)
            update SENSOR_TABLE
                set `last-seq` = #{data["seq"]},
                    mtime = "#{ts}",
                    state = "#{state}"
                where id = "#{id}";
          EOQ

          db.query("commit;")

        rescue NotUpdated
          Log.debug("mysql2") {"skip seq:#{data["seq"]}"}
          db.query("rollback;")

        rescue => e
          Log.error("mysql2") {"error occurd \"#{e.message}\""}
          db.query("rollback;")
          raise(e)

        ensure
          db&.close
        end

        def set_stall(id)
          Log.debug("mysql2") {"set_stall(#{id[0,8]})"}

          db = Mysql2::Client.new(DB_CRED)

          db.query("start transaction;")

          db.query(<<~EOQ)
            update SENSOR_TABLE
                set mtime = NOW(), state = "STALL" where id = "#{id}";
          EOQ

          db.query("commit;")

        rescue => e
          Log.error("mysql2") {"error occurd \"#{e.message}\""}
          db.query("rollback;")
          raise(e)

        ensure
          db&.close
        end

        def update_timestamp(id, ts)
          Log.debug("mysql2") {"update_timestamp(#{id[0,8]}, #{ts})"}

          db = Mysql2::Client.new(DB_CRED)

          db.query("start transaction;")

          db.query(<<~EOQ)
            update SENSOR_TABLE set mtime = "#{ts}" where id = "#{id}";
          EOQ

          db.query("commit;")

        rescue => e
          Log.error("mysql2") {"error occurd \"#{e.message}\""}
          db.query("rollback;")
          raise(e)

        ensure
          db&.close
        end

        def regist_unknown(addr, ts)
          Log.debug("mysql2") {"regist_unknown(#{addr}, #{ts})"}

          db = Mysql2::Client.new(DB_CRED)

          db.query("start transaction;")

          db.query(<<~EOQ)
            insert into SENSOR_TABLE
                values ("#{addr}",
                        "#{SecureRandom.uuid}",
                        "#{ts}",
                        "#{ts}",
                        NULL,
                        "UNKNOWN",
                        "UNKNOWN",
                        NULL);
          EOQ

          db.query("commit;")

        rescue => e
          Log.error("mysql2") {"error occurd \"#{e.message}\""}
          db.query("rollback;")
          raise(e)

        ensure
          db&.close
        end
      end
    end
  end
end
