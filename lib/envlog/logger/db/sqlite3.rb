#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'sqlite3'

module EnvLog
  module Logger
    module DBA
      DB_PATH = Config.fetch_path("database", "sqlite3", "path")

      class << self
        def db
          if not @db
            @db = SQLite3::Database.new(DB_PATH.to_s)
            @db.busy_handler {
              $logger.error("db") {"database access is conflict, retry."}
              sleep(0.1)
              true
            }
          end

          return @db
        end
        private :db

        def mutex
          return @mutex ||= Mutex.new
        end
        private :mutex

        def put_data(d)
          mutex.synchronize {
            begin
              db.transaction

              id   = db.get_first_value(<<~EOQ, d["addr"])
                select id from SENSOR_TABLE where addr = ?;
              EOQ

              raise(NotRegisterd) if not id

              seq  = db.get_first_value(<<~EOQ, id)
                select `last-seq` from SENSOR_TABLE where id = ?;
              EOQ

              raise(NotUpdated) if d["seq"] == seq

              args = [
                id,
                d["temp"],
                d["hum"],
                d["a/p"],
                d["rssi"],
                d["vbat"],
                d["vbus"]
              ]

              db.query(<<~EOQ, *args)
                insert into DATA_TABLE
                    values(?, datetime('now', 'localtime'), ?, ?, ?, ?, ?, ?);
              EOQ

              db.query(<<~EOQ, d['seq'], id)
                update SENSOR_TABLE
                    set `last-seq` = ?,
                        mtime = datetime('now', 'localtime')
                    where id = ?;
              EOQ

              db.commit

            rescue NotUpdated
              db.rollback

            rescue NotRegisterd => e
              Log.error("db") {
                "unregister sensor requested (#{d["addr"]})"
              }
              db.rollback

            rescue => e
              db.rollback
              raise(e)
            end
          }
        end
      end
    end
  end
end
