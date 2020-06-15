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
    class << self
      def start
        WebServer.start(self)
        WebSocket.start(self)

        EM.run
      end

      def stop
        WebServer.stop
        EM.stop
      end
    end
  end
end
