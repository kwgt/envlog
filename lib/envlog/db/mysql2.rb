#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'mysql2'
require "#{LIB_DIR + "mysql2"}"

module EnvLog
	module Database
    using Mysql2Extender

    DB_CRED = Config.dig(:database, :mysql)

    class << self
      def open_database
        db = Mysql2::Client.new(DB_CRED) 
        db.query_options.merge!(:as => :array)

        yield(db)

      ensure
        db&.close
      end
      private :open_database

      def add_device(addr, descr, psrc)
        open_database { |db|
          begin
            db.query("start transaction;")

            row = db.get_first_row(<<~EOQ, :as => :array)
              select id, state from SENSOR_TABLE where addr = "#{addr}";
            EOQ

            if not row
              #
              # 新規登録の場合
              #
              id = SecureRandom.uuid

              Log.info("add new device #{id[0,8]} (#{addr})")

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

              Log.info("add new device #{id[0,8]} (#{addr})")

              if st == "UNKNWON"
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

            db.query("commit");

          rescue => e
            Log.error("error occurrd (#{e.message})")
            db.query("rollback");
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
        db.query("start transaction;")

        db.query("comit;")

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

        db.query("commit;")

      rescue => e
        db.query("rollback;")
        raise(e)
      end
    }
	end
end
