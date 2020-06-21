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

        def put_data(d)
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

          db.query(<<~EOQ)
            insert into DATA_TABLE
                values ("#{id}",
                        NOW(),
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
                    mtime = NOW()
                where id = "#{id}";
          EOQ

          db.query("commit;")

        rescue NotUpdated
          db.query("rollback;")

        rescue NotRegisterd
          $logger.error("db") {
            "unregister sensor requested (#{d["addr"]})"
          }
          db.query("rollback;")

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
