#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

module EnvLog
  module Logger
    module InputSource
      Exit = Class.new(Exception)

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

        def schema
          return @schema ||= JSONSchemer.schema(SCHEMA["INPUT_DATA"])
        end
        private :schema

        def put_data(json)
          data = JSON.parse(json)
          raise InvalidData.new(data) if not schema.valid?(data)

          DBA.put_data(data)

        rescue JSON::ParserError
          raise ParseError.new(json)
        end
        private :put_data

        def add_source(src)
          case src["type"]
          when "serial"
            add_serial_source(src)

          when "udp"
            add_udp_source(src)

          else
            raise("unknown input source(#{src["type"]})")
          end
        end

        def wait
          threads.each {|thread| thread.join}
        end
      end
    end
  end
end

require_relative "input/serial"
require_relative "input/udp"
