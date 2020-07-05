#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

module EnvLog
  module Logger
    class << self
      def start
        Log.info("main") {"start logger"}

        Config[:source].each {|src| InputSource.add_source(src)}
        InputSource.run
      end

      def list_device
        list = Database.list_device

        if list.empty?
          STDOUT.print("device not found.\n")

        else
          STDOUT.print <<~EOT
            ADDRESS              STATE      DESCRIPTION
            -----------------------------------------------------
          EOT

          list.each { |info|
            STDOUT.printf("%-20s %-10s %s\n",
                          info[:addr],
                          info[:state],
                          info[:descr])
          }
        end
      end

      def add_device(*args)
        if args.size != 3
          raise ArgumentError.new("invalid number of argument")
        end

        addr  = args[0]
        psrc  = args[1].upcase
        descr = args[2]

        if not Schema.valid?(:DEVICE_ADDR, addr)
          raise ArgumentError.new("invalid device address format")
        end

        if not Schema.valid?(:POWER_SOURCE, psrc)
          raise ArgumentError.new("invalid power source string")
        end

        Database.add_device(addr, descr, psrc)
      end

      def remove_device(addr)
        if not Schema.valid?(:DEVICE_ADDR, addr)
          raise ArgumentError.new("invalid device address format")
        end

        if not Database.device_exist?(addr)
          raise ArgumentError.new("device not found")
        end

        Database.remove_device(addr)
      end
    end
  end
end
