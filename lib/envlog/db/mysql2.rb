#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'mysql2'
require 'securerandom'
require "#{LIB_DIR + "mysql2"}"

module EnvLog
	module Database
    using Mysql2Extender

    DB_CRED = Config.dig(:database, :mysql)

    class << self
      def open_database
        db = Mysql2::Client.new(DB_CRED) 
        db.query_options.merge!(:as => :array)

        class << db
          def transaction
            self.query("start transaction;")
          end

          def commit
            self.query("commit;")
          end

          def rollback
            self.query("rollback;")
          end

          def check_exist(addr)
            n = self.get_first_value(<<~EOQ)
              select count(*) from SENSOR_TABLE where addr = "#{addr}";
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
          n = db.get_first_value(<<~EOQ)
            select count(*) from SENSOR_TABLE where addr = "#{addr}";
          EOQ

          return n.zero?.!
        }
      end

      # only use for test
      def clear_sensor_table
        open_database { |db|
          begin
            db.transaction

            db.query(<<~EOQ)
              delete from SENSOR_TABLE;
            EOQ

            db.commit

          rescue => e
            db.rollback
            raise(e)
          end
        }
      end

      # only use for test
      def get_device_info(addr)
        open_database { |db|
          row = db.get_first_row(<<~EOQ)
            select id, addr, state, `pow-source`, descr
                from SENSOR_TABLE where addr = "#{addr}";
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
            db.query(<<~EOQ)
              insert into SENSOR_TABLE
                  values ("#{addr}",
                          "#{SecureRandom.uuid}",
                          NOW(),
                          NOW(),
                          NULL,
                          "UNKNOWN",
                          "#{state.to_s}",
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
          rows = db.query(<<~EOQ, :as => :array)
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

            row = db.get_first_row(<<~EOQ, :as => :array)
              select id, state from SENSOR_TABLE where addr = "#{addr}";
            EOQ

            if not row
              #
              # 新規登録の場合
              #
              id = SecureRandom.uuid

              Log.info("mysql2"){"add new device #{id[0,8]} (#{addr})"}

              db.query(<<~EOQ)
                insert into SENSOR_TABLE
                    values ("#{addr}",
                            "#{id}",
                            NOW(),
                            NOW(),
                            #{descr.to_mysql},
                            "#{psrc.upcase}",
                            "READY",
                            NULL);
              EOQ

            else
              id = row[0]
              st = row[1]

              Log.info("mysql2"){"add new device #{id[0,8]} (#{addr})"}

              if st == "UNKNOWN"
                #
                # 不明デバイスとして登録済みの場合
                #
                db.query(<<~EOQ)
                  update SENSOR_TABLE
                      set mtime  = NOW(),
                          descr  = #{descr.to_mysql},
                          `pow-source` = "#{psrc.upcase}",
                          state        = "READY",
                          `last-seq`   = NULL
                      where id = "#{id}";
                EOQ

              else
                #
                # 稼働中のデバイスが指定された場合
                #
                raise DeviceBusy.new("device #{addr} is working now")
              end
            end

            db.commit

          rescue => e
            Log.error("mysql2"){"error occurrd (#{e.message})"}
            db.rollback
            raise(e)
          end
        }
      end

      def set_description(addr, descr)
        Log.info("mysql2"){"set description #{addr}"}

        open_database { |db|
          begin
            db.transaction

            db.check_exist(addr)

            db.query(<<~EOQ)
              update SENSOR_TABLE set mtime = NOW(), descr = #{descr.to_mysql}
                  where addr = "#{addr}";
            EOQ

            db.commit

          rescue => e
            Log.error("mysql2"){"error occurrd (#{e.message})"}
            db.rollback
            raise(e)
          end
        }
      end

      def set_power_source(addr, src)
        Log.info("mysql2"){"set power source #{addr}"}

        if not valid_power_source?(src)
          raise(ArgumentError.new("invalid power source"))
        end

        open_database { |db|
          begin
            db.transaction

            db.check_exist(addr)

            db.query(<<~EOQ)
              update SENSOR_TABLE
                  set mtime = NOW(), `pow-source` = "#{src.upcase}"
                  where addr = "#{addr}";
            EOQ

            db.commit

          rescue => e
            Log.error("mysql2"){"error occurrd (#{e.message})"}
            db.rollback
            raise(e)
          end
        }
      end

      def activate(addr)
        Log.info("mysql2"){"activate #{addr}"}

        open_database { |db|
          begin
            db.transaction

            db.check_exist(addr)

            row = db.get_first_row(<<~EOQ)
              select `pow-source`, state
                  from SENSOR_TABLE where addr = "#{addr}";
            EOQ

            if not valid_power_source?(row[0])
              raise("power source is not set")
            end

            if row[1] != "UNKNOWN"
              raise("state violation")
            end

            db.query(<<~EOQ)
              update SENSOR_TABLE
                  set mtime = NOW(), state = "READY" where addr = "#{addr}";
            EOQ

            db.commit

          rescue => e
            Log.error("mysql2"){"error occurrd (#{e.message})"}
            db.rollback
            raise(e)
          end
        }
      end

      def pause(addr)
        Log.info("mysql2"){"pause #{addr}"}

        open_database { |db|
          begin
            db.transaction

            db.check_exist(addr)

            st = db.get_first_value(<<~EOQ)
              select state from SENSOR_TABLE where addr = "#{addr}";
            EOQ

            raise("state violation") if not recording_state?(st)

            db.query(<<~EOQ)
              update SENSOR_TABLE
                  set mtime = NOW(), state = "PAUSE" where addr = "#{addr}";
            EOQ

            db.commit

          rescue => e
            Log.error("mysql2"){"error occurrd (#{e.message})"}
            db.rollback
            raise(e)
          end
        }
      end

      def resume(addr)
        Log.info("mysql2"){"resume #{addr}"}

        open_database { |db|
          begin
            db.transaction

            db.check_exist(addr)

            st = db.get_first_value(<<~EOQ)
              select state from SENSOR_TABLE where addr = "#{addr}";
            EOQ

            raise("state violation") if not pause_state?(st)

            db.query(<<~EOQ)
              update SENSOR_TABLE
                  set mtime = NOW(), state = "NORMAL" where addr = "#{addr}";
            EOQ

            db.commit

          rescue => e
            Log.error("mysql2"){"error occurrd (#{e.message})"}
            db.rollback
            raise(e)
          end
        }
      end

      def remove_device(addr)
        open_database { |db|
          begin
            db.transaction

            db.query(<<~EOQ)
              delete from SENSOR_TABLE where addr = "#{addr}";
            EOQ

            db.commit

          rescue => e
            Log.error("mysql2"){"error occurrd (#{e.message})"}
            db.rollback
            raise(e)
          end
        }
      end
    end

    #
    # テーブル作成
    # ※とりあえずライブラリ読み込み時に作ってみる
    #
    self.open_database { |db|
      begin
        db.transaction

        #
        # センサー定義テーブル
        #   ※MariaDBでは、timestampを含むテーブルを作成した場合、Extraに
        #     勝手に"on update CURRENT_TIMESTAMP"が付与されてしまうため、
        #     update 時に予期せぬ動作をすることがある。これを防ぐためデフ
        #     ォルト設定を行っている(default CURENT_TIMESTAMPを指定すると
        #     Extraが付与されない)。
        #
        db.query(<<~EOQ)
          create table if not exists SENSOR_TABLE (
            addr         varchar(64) unique, /* デバイスアドレス          */
            id           char(36) unique,    /* センサーID (UUID)         */
            ctime        timestamp default CURRENT_TIMESTAMP, /* 登録日時 */
            mtime        timestamp default CURRENT_TIMESTAMP, /* 更新日時 */
            descr        text,               /* 端末概要                  */
            `pow-source` varchar(16),        /* 外部電源の種別            */
            state        varchar(16),        /* 状態                      */
            `last-seq`   integer,            /* 最終シーケンス番号        */

            primary key (id)
          );
        EOQ

        db.query(<<~EOQ)
          create table if not exists DATA_TABLE (
            sensor     char(36),           /* センサーID (UUID)           */
            time       timestamp,          /* 記録日時                    */
            temp       float,              /* 気温                        */
            humidity   float,              /* 湿度                        */
            `air-pres` float,              /* 気圧                        */
            rssi       integer,            /* 計測時のRSSI                */
            vbat       float,              /* 計測時の電池電圧            */
            vbus       float,              /* 計測時の外部電源電圧        */

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
