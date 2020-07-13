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
  module Database
    DB_PATH = Config.fetch_path(:database, :sqlite3, :path)

    class << self
      def open_database
        db = SQLite3::Database.new(DB_PATH.to_s)
        db.busy_handler {
          sleep(0.1)
          true
        }

        class << db
          def check_exist(addr)
            n = self.get_first_value(<<~EOQ, addr)
              select count(*) from SENSOR_TABLE where addr = ?;
            EOQ

            raise(DeviceNotFound.new("device not found")) if n.zero?
          end
        end

        yield(db)

      ensure
        db&.close
      end
      private :open_database

      def device_exist?(addr)
        open_database { |db|
          n = db.get_first_value(<<~EOQ, addr)
            select count(*) from SENSOR_TABLE where addr = ?;
          EOQ

          return n.zero?.!
        }
      end

      # only use for test
      def clear_sensor_table
        open_database { |db|
          begin
            db.transaction
            db.execute(<<~EOQ)
              delete from SENSOR_TABLE;
            EOQ
            db.commit

          rescue
            db.rollback
          end
        }
      end

      # only use for test
      def get_device_info(addr)
        open_database { |db|
          row = db.get_first_row(<<~EOQ, addr)
            select id, addr, state, `pow-source`, descr
                from SENSOR_TABLE where addr = ?;
          EOQ

          ret = {
            :id    => row[0],
            :addr  => row[1],
            :state => row[2],
            :psrc  => row[3],
            :descr => row[4],
          }

          return ret
        }
      end

      # only use for test
      def add_dummy_device(addr, state)
        open_database { |db|
          begin
            db.transaction
            db.execute(<<~EOQ, addr, SecureRandom.uuid, state.to_s)
              insert into SENSOR_TABLE
                  values (?,
                          ?,
                          datetime('now', 'localtime'),
                          datetime('now', 'localtime'),
                          NULL,
                          "UNKNOWN",
                          ?,
                          NULL);
            EOQ
            db.commit

          rescue => e
            db.rollback
            raise(e)
          end
        }
      end

      def list_device
        open_database { |db|
          rows = db.execute(<<~EOQ)
            select id, addr, state, descr from SENSOR_TABLE;
          EOQ

          ret = rows.inject([]) { |m, n|
            m << {
              :id    => n[0],
              :addr  => n[1],
              :state => n[2],
              :descr => n[3],
            }
          }

          return ret
        }
      end

      def add_device(addr, descr, psrc)
        open_database { |db|
          begin
            db.transaction

            row = db.get_first_row(<<~EOQ, addr)
              select id, state from SENSOR_TABLE where addr = ?;
            EOQ

            if not row
              #
              # 新規登録の場合
              #
              id = SecureRandom.uuid

              Log.info("sqlite3"){"add new device #{id[0,8]} (#{addr})"}

              db.execute(<<~EOQ, addr, SecureRandom.uuid, descr, psrc)
                insert into SENSOR_TABLE
                    values (?,
                            ?,
                            datetime('now', 'localtime'),
                            datetime('now', 'localtime'),
                            ?,
                            ?,
                            "READY",
                            NULL);
              EOQ


            else
              id = row[0]
              st = row[1]

              Log.info("sqlite3"){"add new device #{id[0,8]} (#{addr})"}

              if st == "UNKNOWN"
                #
                # 不明デバイスとして登録済みだった場合
                #
                db.execute(<<~EOQ, descr, psrc, id)
                  update SENSOR_TABLE
                      set mtime        = datetime('now', 'localtime'),
                          descr        = ?,
                          `pow-source` = ?,
                          state        = "READY",
                          `last-seq`   = NULL
                      where id = ?;
                EOQ

              else
                #
                # 稼働中のデバイスが指定された場合
                #
                raise DeviceBusy.new("device #{addr} is working now")
              end
            end

            db.commit;

          rescue => e
            Log.error("sqlite3"){"error occurrd (#{e.message})"}
            db.rollback
            raise(e)
          end
        }
      end

      def set_description(addr, descr)
        Log.info("sqlite3"){"set description #{addr}"}

        open_database { |db|
          begin
            db.transaction

            db.check_exist(addr)

            db.execute(<<~EOQ, descr, addr)
              update SENSOR_TABLE
                  set mtime = datetime('now', 'localtime'), descr = ?
                  where addr = ?;
            EOQ

            db.commit

          rescue => e
            Log.error("sqlite3"){"error occurrd (#{e.message})"}
            db.rollback
            raise(e)
          end
        }
      end

      def set_power_source(addr, src)
        Log.info("sqlite3"){"set power source #{addr}"}

        if not valid_power_source?(src)
          raise(ArgumentError.new("invalid power source"))
        end

        open_database { |db|
          begin
            db.transaction

            db.check_exist(addr)

            db.execute(<<~EOQ, src.upcase, addr)
              update SENSOR_TABLE
                  set mtime = datetime('now', 'localtime'), `pow-source` = ?
                  where addr = ?;
            EOQ

            db.commit

          rescue => e
            Log.error("sqlite3"){"error occurrd (#{e.message})"}
            db.rollback
            raise(e)
          end
        }
      end

      def activate(addr)
        Log.info("sqlite3"){"activate #{addr}"}

        open_database { |db|
          begin
            db.transaction

            db.check_exist(addr)

            row = db.get_first_row(<<~EOQ, addr)
              select `pow-source`, state from SENSOR_TABLE where addr = ?;
            EOQ

            if not valid_power_source?(row[0])
              raise("power source is not set")
            end

            if row[1] != "UNKNOWN"
              raise("state violation")
            end

            db.execute(<<~EOQ, addr)
              update SENSOR_TABLE
                  set mtime = datetime('now', 'localtime'), state = "READY"
                  where addr = ?;
            EOQ

            db.commit

          rescue => e
            Log.error("sqlite3"){"error occurrd (#{e.message})"}
            db.rollback
            raise(e)
          end
        }
      end

      def pause(addr)
        Log.info("sqlite3"){"pause #{addr}"}

        open_database { |db|
          begin
            db.transaction

            db.check_exist(addr)

            st = db.get_first_value(<<~EOQ, addr)
              select state from SENSOR_TABLE where addr = ?;
            EOQ

            raise("state violation") if not recording_state?(st)

            db.execute(<<~EOQ, addr)
              update SENSOR_TABLE
                  set mtime = datetime('now', 'localtime'), state = "PAUSE"
                  where addr = ?;
            EOQ

            db.commit

          rescue => e
            Log.error("sqlite3"){"error occurrd (#{e.message})"}
            db.rollback
            raise(e)
          end
        }
      end

      def resume(addr)
        Log.info("sqlite3"){"resume #{addr}"}

        open_database { |db|
          begin
            db.transaction

            db.check_exist(addr)

            st = db.get_first_value(<<~EOQ, addr)
              select state from SENSOR_TABLE where addr = ?;
            EOQ

            raise("state violation") if recording_state?(st)

            db.execute(<<~EOQ, addr)
              update SENSOR_TABLE
                  set mtime = datetime('now', 'localtime'), state = "NORMAL"
                  where addr = ?;
            EOQ

            db.commit

          rescue => e
            Log.error("sqlite3"){"error occurrd (#{e.message})"}
            db.rollback
            raise(e)
          end
        }
      end

      def remove_device(addr)
        open_database { |db|
          begin
            db.transaction

            db.check_exist(addr)

            db.execute(<<~EOQ, addr)
              delete from SENSOR_TABLE where addr = ?;
            EOQ

            db.commit

          rescue => e
            Log.error("sqlite3"){"error occurrd (#{e.message})"}
            db.rollback
            raise(e)
          end
        }
      end
    end

    #
    # テーブル作成
    # ※ とりあえずライブラリ読み込み時に作ってみる
    #
    self.open_database { |db|
      begin
        db.transaction

        #
        # センサー定義テーブル
        #
        db.execute(<<~EOQ)
          create table if not exists SENSOR_TABLE (
            addr         text unique, /* デバイスアドレス          */
            id           text unique, /* センサID(UUID)            */
            ctime        timestamp,   /* 登録日時                  */
            mtime        timestamp,   /* 更新日時                  */
            descr        text,        /* 端末概要                  */
            `pow-source` text,        /* 外部電源の種別            */
            state        text,        /* 状態                      */
            `last-seq`   integer,     /* 最終シーケンス番号        */

            primary key (id)
          ); 
        EOQ

        #
        # データテーブル
        #
        db.execute(<<~EOQ)
          create table if not exists DATA_TABLE (
            sensor     text,         /* センサーID (UUID)          */
            time       timestamp,    /* 記録日時                   */
            temp       numeric,      /* 気温                       */
            humidity   numeric,      /* 湿度                       */
            `air-pres` numeric,      /* 気圧                       */
            rssi       integer,      /* 計測時のRSSI               */
            vbat       numeric,      /* 計測時の電池電圧           */
            vbus       numeric,      /* 計測時の外部電源電圧       */

            primary key (time, sensor)
          );
        EOQ

        db.commit

      rescue => e
        db.rollback
        raise(e)
      end
    }
  end
end
