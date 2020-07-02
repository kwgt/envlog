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
    end
  end
end
