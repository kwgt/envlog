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
          file = Config.dig(:log, :file)

          if (not file) || file == "-"
            @device = STDOUT
          else
            @device = File.open(Config.dig(:log, :file), "a")
          end

          @device.sync = true
        end

        return @device
      end

      def setup
        @logger.close if @logger

        if not Config[:log]
          obj  = Logger.new(STDOUT)

        else
          age  = Config.dig(:log, :shift_age)  || 0
          size = Config.dig(:log, :shift_size) || (1024 * 1024)

          case Config.dig(:log, :level)
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

          obj = Logger.new(device, age, size, :level => level)
        end

        obj.datetime_format = "%Y-%m-%dT%H:%M:%S"
        obj.freeze

        @logger = obj
      end

      attr_reader :logger

      def debug(*args, &b)
        raise("not opened yet") if not @logger
        @logger.debug(*args, &b)
      end

      def error(*args, &b)
        raise("not opened yet") if not @logger
        @logger.error(*args, &b)
      end

      def fatal(*args, &b)
        raise("not opened yet") if not @logger
        @logger.fatal(*args, &b)
      end

      def info(*args, &b)
        raise("not opened yet") if not @logger
        @logger.info(*args, &b)
      end

      def unknown(*args, &b)
        raise("not opened yet") if not @logger
        @logger.unknown(*args, &b)
      end

      def warn(*args, &b)
        raise("not opened yet") if not @logger
        @logger.warn(*args, &b)
      end

      def close
        raise("not opened yet") if not @logger
        @logger.close
        @logger = nil
      end
    end
  end
end
