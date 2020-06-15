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
      class << self
        def add_udp_source(src)
          raise NotImplementedError.new("Not implemented yet")
        end
        private :add_udp_source
      end
    end
  end
end
