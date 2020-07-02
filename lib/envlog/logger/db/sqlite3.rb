#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'sqlite3'
require 'securerandom'
require "#{LIB_DIR}/db/sqlite3.rb"

module EnvLog
  module Logger
    module DBA
      DB_PATH = Config.fetch_path(:database, :sqlite3, :path)

      class << self
        def db
          if not @db
            @db = SQLite3::Database.new(DB_PATH.to_s)
            @db.busy_handler {
              Log.error("db") {"database access is conflict, retry."}
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

        def put_data(id, ts, data, state)
          mutex.synchronize {
            begin
              Log.debug("sqlite3") {
                "put_data(#{id[0,8]}, #{ts}, #{data["seq"]})"
              }

              db.transaction

              seq  = db.get_first_value(<<~EOQ, id)
                select `last-seq` from SENSOR_TABLE where id = ?;
              EOQ

              raise(NotUpdated) if data["seq"] == seq

              args = [
                id,
                ts,
                data["temp"],
                data["hum"],
                data["a/p"],
                data["rssi"],
                data["vbat"],
                data["vbus"]
              ]

              db.query(<<~EOQ, *args)
                insert into DATA_TABLE
                    values(?,
                           datetime(?),
                           ?,
                           ?,
                           ?,
                           ?,
                           ?,
                           ?);
              EOQ

              db.query(<<~EOQ, data['seq'], ts, state, id)
                update SENSOR_TABLE
                    set `last-seq` = ?,
                        mtime = datetime(?),
                        state = ?
                    where id = ?;
              EOQ

              db.commit

            rescue NotUpdated
              Log.debug("sqlite3") {"sekip seq:#{data["seq"]}"}
              db.rollback

            rescue => e
              Log.error("sqlite3") {"error occurred \"#{e.message}\""}
              db.rollback
              raise(e)
            end
          }
        end

        def set_stall(id)
          mutex.synchronize {
            begin
              Log.debug("sqlite3") {"set_stall(#{id[0,8]})"}

              db.transaction

              db.execute(<<~EOQ, id)
                update SENSOR_TABLE
                    set mtime = datetime('now', 'localtime'),
                        state = "STALL"
                    where id = ?;
              EOQ

              db.commit

            rescue => e
              Log.error("sqlite3") {"error occurred \"#{e.message}\""}
              db.rollback
              raise(e)
            end
          }
        end

        def update_timestamp(id, ts)
          mutex.synchronize {
            begin
              Log.debug("sqlite3") {"update_timestamp(#{id[0,8]}, #{ts})"}

              db.transaction

              db.execute(<<~EOQ, ts, id)
                update SENSOR_TABLE set mtime = datetime(?) where id = ?;
              EOQ

              db.commit

            rescue => e
              Log.error("sqlite3") {"error occurred \"#{e.message}\""}
              db.rollback
              raise(e)
            end
          }
        end

        def regist_unknown(addr, ts)
          mutex.synchronize {
            begin
              Log.debug("sqlite3") {"regist_unknown(#{addr}, #{ts})"}

              db.transaction

              db.execute(<<~EOQ, addr, SecureRandom.uuid)
                insert into SENSOR_TABLE
                    values (?,
                            ?,
                            datetime(?),
                            datetime(?),
                            NULL,
                            "UNKNOWN",
                            "UNKNOWN",
                            NULL);
              EOQ

              db.commit

            rescue => e
              Log.error("sqlite3") {"error occurred \"#{e.message}\""}
              db.rollback
              raise(e)
            end
          }
        end
      end
    end
  end
end
