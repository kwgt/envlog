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
        Log.info("main") {"viewer started."}
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
        return @sensor_tbl ||= DBA.open {|db| db.poll_sensor()}
      end

      def poll_sensor
        res = DBA.open {|db| db.poll_sensor()}

        res.each_pair { |id, mtime|
          if mtime > sensor_tbl[id]
            Log.debug("main") {"sensor #{id} updated"}
            WebSocket.broadcast(:update_sensor, id)
            sensor_tbl[id] = mtime
          end
        }
      end
    end
  end
end
