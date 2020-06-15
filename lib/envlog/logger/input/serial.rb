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
            tty  = src["port"]
            $logger.info(tty) {"add serial input source"}

            src  = src.select {|x| x != "type"}
            port = Serial.new(**src)

            loop {
              begin
                json = port.gets
                $logger.debug(tty) {"receive: #{json.dump}"}

                put_data(json)

              rescue JSON::ParserError => e
                $logger.error(tty) {"invalid json #{e.json.dump}"}

              rescue InvalidData => e
                $logger.error(tty) {"rejected #{e.data.inspect}"}

              rescue Exit
                $logger.info(tty) {"exit serial input thread"}
                break
              end
            }
          }
        end
        private :add_serial_source
      end
    end
  end
end
