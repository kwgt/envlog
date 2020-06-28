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
      DB_PATH = Config.fetch_path(:database, :sqlite3, :path)

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

        def get_alives
          rows = mutex.synchronize {
            db.execute(<<~EOQ)
              select addr, id from SENSOR_TABLE where addr is not NULL;
            EOQ
          }

          return rows.inject([]) {|m, n| m << {:addr => n[0], :id => n[1]}}
        end

        def get_sensor_info(addr)
          row = mutex.synchronize {
            db.get_first_row(<<~EOQ, addr)
              select id, `pow-source`, state
                  from SENSOR_TABLE where addr = ?;
            EOQ
          }

          if row
            ret = {
              :id     => row[0],
              :powsrc => row[1],
              :state  => row[2],
            }

          else
            row = nil
          end

          return ret
        end

        def poll_sensor
          rows = db.execute(<<~EOQ)
            select id, mtime, state from SENSOR_TABLE where addr is not NULL;
          EOQ

          ret = rows.inject({}) { |m, n|
            m[n[0]] = {:mtime => n[1], :state => n[2]}; m
          }

          return ret
        end

        def put_data(d, s)
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

              now  = Time.now.to_i
              args = [
                id,
                now,
                d["temp"],
                d["hum"],
                d["a/p"],
                d["rssi"],
                d["vbat"],
                d["vbus"]
              ]

              db.query(<<~EOQ, *args)
                insert into DATA_TABLE
                    values(?, datetime(?, 'localtime'), ?, ?, ?, ?, ?, ?);
              EOQ

              db.query(<<~EOQ, d['seq'], now, s, id)
                update SENSOR_TABLE
                    set `last-seq` = ?,
                        mtime = datetime(?, 'localtime'),
                        state = ?
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

        def set_stall(id)
          mutex.synchronize {
            begin
              db.trasaction
              eb.execute(<<~EOQ, id)
                update SENSOR_TABLE
                    set mtime = datetime('now', 'localtime'),
                        state = "STALL"
                    where id = ?;
              EOQ

              db.commit

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
