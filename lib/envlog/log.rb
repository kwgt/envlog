#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'logger'

module EnvLog
  module Log
    using DeepFreezer

    class << self
      def device
        if not @device
          file = CONFIG.dig("log", "file")

          if (not file) || file == "-"
            @device = STDOUT
          else
            @device = File.open(CONFIG.dig("log", "file"), "a")
          end

          @device.sync = true
        end

        return @device
      end

      def open
        if not CONFIG["log"]
          ret = Logger.new(STDOUT)

        else
          age  = CONFIG.dig("log", "shift_age")  || 0
          size = CONFIG.dig("log", "shift_size") || (1024 * 1024)

          case CONFIG.dig("log", "level")
          when "UNKNOWN"
            level = Logger::UNKNOWN

          when "FATAL"
            level = Logger::FATAL

          when "ERROR"
            level = Logger::ERROR

          when "WARN"
            level = Logger::WARN

          when "INFO"
            level = Logger::INFO

          when "DEBUG"
            level = Logger::DEBUG

          else
            level = Logger::INFO
          end

          ret = Logger.new(device, age, size, :level => level)
        end

        ret.datetime_format = "%Y-%m-%dT%H:%M:%S"
        ret.freeze

        return ret
      end
    end
  end
end
