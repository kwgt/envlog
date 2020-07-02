#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'sqlite3'
require "#{LIB_DIR}/db/sqlite3"

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

        yield(db)

      ensure
        db&.close
      end
      private :open_database

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
