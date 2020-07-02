#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'mysql2'

module EnvLog
	module Database
    DB_CRED = Config.dig(:database, :mysql)

    class << self
      def open_database
        db = Mysql2::Client.new(DB_CRED) 

        yield(db)

      ensure
        db&.close
      end
      private :open_database
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
