#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'sqlite3'
require 'securerandom'

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

        def put_data(id, data, state)
          mutex.synchronize {
            begin
              db.transaction

              seq  = db.get_first_value(<<~EOQ, id)
                select `last-seq` from SENSOR_TABLE where id = ?;
              EOQ

              raise(NotUpdated) if data["seq"] == seq

              now  = Time.now.to_i
              args = [
                id,
                now,
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
                           datetime(?, 'unixepoch', 'localtime'),
                           ?,
                           ?,
                           ?,
                           ?,
                           ?,
                           ?);
              EOQ

              db.query(<<~EOQ, data['seq'], now, state, id)
                update SENSOR_TABLE
                    set `last-seq` = ?,
                        mtime = datetime(?, 'unixepoch', 'localtime'),
                        state = ?
                    where id = ?;
              EOQ

              db.commit

            rescue NotUpdated
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
              db.transaction

              db.execute(<<~EOQ, id)
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

        def update_timestamp(id)
          mutex.synchronize {
            begin
              db.transaction

              db.execute(<<~EOQ, addr)
                update SENSOR_TABLE
                    set mtime = datetime('now', 'localtime') where id = ?;
              EOQ

              db.commit

            rescue => e
              db.rollback
              raise(e)
            end
          }
        end

        def regist_unknown(addr)
          mutex.synchronize {
            begin
              db.transaction

              db.execute(<<~EOQ, addr, SecureRandom.uuid)
                insert into SENSOR_TABLE
                    values (?,
                            ?,
                            datetime('now', 'localtime'),
                            datetime('now', 'localtime'),
                            NULL
                            "UNKNOWN",
                            "UNKNOWN",
                            NULL);
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
