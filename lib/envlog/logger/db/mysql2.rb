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

        def put_data(id, data, state)
          db = Mysql2::Client.new(DB_CRED)

          db.query("start transaction;")

          seq = db.get_first_value(<<~EOQ)
            select `last-seq` from SENSOR_TABLE where id = "#{id}";
          EOQ

          raise(NotUpdated) if data["seq"] == seq

          now = Time.now.to_s

          db.query(<<~EOQ)
            insert into DATA_TABLE
                values ("#{id}",
                        "#{now}",
                        #{data["temp"]},
                        #{data["hum"]},
                        #{data["a/p"]},
                        #{data["rssi"]},
                        #{data["vbat"]},
                        #{data["vbus"]});
          EOQ

          db.query(<<~EOQ)
            update SENSOR_TABLE
                set `last-seq` = #{data["seq"]},
                    mtime = "#{now}",
                    state = "#{state}"
                where id = "#{id}";
          EOQ

          db.query("commit;")

        rescue NotUpdated
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
                set mtime = NOW(), state = "STALL" where id = "#{id}";
          EOQ

          db.query("commit;")

        rescue => e
          db.query("rollback;")
          raise(e)

        ensure
          db&.close
        end

        def update_timestamp(id)
          db = Mysql2::Client.new(DB_CRED)

          db.query("start transaction;")

          db.query(<<~EOQ)
            update SENSOR_TABLE set mtime = NOW() where id = "#{id}";
          EOQ

          db.query("commit;")

        rescue => e
          db.query("rollback;")
          raise(e)

        ensure
          db&.close
        end

        def regist_unknown(addr)
          db = Mysql2::Client.new(DB_CRED)

          db.query("start transaction;")

          db.query(<<~EOQ)
            insert into SENSOR_TABLE
                values ("#{addr}",
                        "#{SecureRandom.uuid}",
                        NOW(),
                        NOW(),
                        NULL,
                        "UNKNOWN",
                        "UNKNOWN",
                        NULL);
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
