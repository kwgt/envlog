#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'eventmachine'

module EnvLog
  module Viewer
    POLL_INTERVAL = 30

    class << self
      def start
        WebServer.start(self)
        WebSocket.start(self)

        EM.run {
          EM.add_periodic_timer(10) {poll_sensor()}
        }
      end

      def stop
        WebServer.stop
        EM.stop
      end

      def sensor_tbl
        @sensor_tbl ||= -> {
          begin
            db = DBA.open()
            return db.poll_sensor
          ensure
            db&.close
          end
        }.()

        return @sensor_tbl 
      end

      def poll_sensor
        db = DBA.open()
        res = db.poll_sensor()

        res.each_pair { |id, mtime|
          if mtime < sensor_tbl[id]
            WebSocket.broadcast(:update_sensor, id)
            sensor_tbl[id] = mtime
          end
        }

      rescue
        db&.close
      end
    end
  end
end
