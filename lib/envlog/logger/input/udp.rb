#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'ipaddr'
require 'socket'

module EnvLog
  module Logger
    module InputSource
      class << self
        def add_udp_source(src)
          threads << Thread.fork {
            begin
              addr = IPAddr.new(src[:bind] || "::")

              if addr.ipv6?
                ep = "UDP([#{addr}]:#{src[:port]})"
              else
                ep = "UDP(#{addr}:#{src[:port]})"
              end

              Log.info(ep) {"add UDP input source"}

              sock = UDPSocket.open(addr.family)
              sock.bind(addr.to_s, src[:port])

              loop {
                begin
                  data = unpack_v4_data(sock.recv(1024).bytes)
                  Log.debug(ep) {"receive: #{data}"}

                  put_data(data)

                rescue NotSupported => e
                  Log.error(ep) {e.message}

                rescue InvalidData => e
                  Log.error(ep) {"rejected invalid data #{e.data}"}

                rescue => e
                  Log.error(ep) {"error occurred (#{e.message})"}
                end
              }

            rescue Exit
              Log.info(ep) {"exit UDP input thread"}

            ensure
              sock&.close if defined?(sock)
            end
          }
        end
        private :add_udp_source
      end
    end
  end
end
