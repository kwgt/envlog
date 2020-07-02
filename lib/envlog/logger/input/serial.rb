#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'ffi-serial'
require 'json'
require 'json_schemer'

module EnvLog
  module Logger
    module InputSource
      class << self
        def add_serial_source(src)
          threads << Thread.fork {
            tty  = src[:port]
            Log.info(tty) {"add serial input source"}

            src  = src.select {|x| x != :type}
            port = Serial.new(**src)

            loop {
              begin
                json = port.gets
                Log.debug(tty) {"receive: #{json.dump}"}

                put_data(json)

              rescue JSON::ParserError => e
                Log.error(tty) {"invalid json #{e.json.dump}"}

              rescue InvalidData => e
                Log.error(tty) {"rejected #{e.data.inspect}"}

              rescue Exit
                break
              end
            }

            Log.info(tty) {"exit serial input thread"}
          }
        end
        private :add_serial_source
      end
    end
  end
end
