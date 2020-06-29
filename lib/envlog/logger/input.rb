#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'time'

module EnvLog
  module Logger
    module InputSource
      MONITOR_INTERVAL = 60
      STALL_THRESHOLD  = 300

      class Exit < Exception; end

      class ParseError < StandardError
        def initialize(json)
          super("JSON parse error")
          @json = json
        end
        attr_reader :json
      end

      class InvalidData < StandardError
        def initialize(data)
          super("Validation error")
          @data = data
        end
        attr_reader :data
      end

      class << self
        def threads
          return @thread ||= []
        end
        private :threads

        def put_data(json)
          data = JSON.parse(json)
          raise InvalidData.new(data) if not Schema.valid?(:INPUT_DATA, data)

          info = DBA.get_sensor_info(data["addr"])
          if info
            if info[:state] != "CLOSED"
              case info[:powsrc]
              when "STABLE"
                state = "NORMAL"

              when "BATTERY"
                state = (vbus > 4.0)? "NORMAL": "DEAD-BATTERY"
              end

              DBA.put_data(data, state)
            end

          else
            Log.error("input") {
              "data received from unknown device (#{data["addr"]})"
            }
          end

        rescue JSON::ParserError
          raise ParseError.new(json)
        end
        private :put_data

        def monitor_thread
          Log.info("input") {"start moinitor thread"}

          loop {
            begin
              sleep(MONITOR_INTERVAL)

              now = Time.now

              DBA.poll_sensor.each { |id, info|
                next if info[:state] != "NORMAL"

                if now - Time.parse(info[:mtime]) > STALL_THRESHOLD
                  DBA.set_stall(id)
                end
              }

            rescue Exit
              break
            end
          }

          Log.info("input") {"exit moinitor thread"}
        end
        private :monitor_thread

        def add_source(src)
          case src[:type]
          when "serial"
            add_serial_source(src)

          when "udp"
            add_udp_source(src)

          else
            raise("unknown input source(#{src["type"]})")
          end
        end

        def wait
          threads << Thread.fork {monitor_thread()}
          threads.each {|thread| thread.join}
        end
      end
    end
  end
end

require_relative "input/serial"
require_relative "input/udp"
