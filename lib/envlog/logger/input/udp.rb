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
                json = v4data_to_json(sock.recv(1024).bytes)
                Log.debug(ep) {"receive: #{json.dump}"}

                put_data(json)

              rescue Exit
                break

              rescue NotSupported => e
                Log.debug(ep) {e.message}

              rescue => e
                Log.error(ep) {"error occurred (#{e.message})"}
              end
            }

            sock.close
            Log.info(ep) {"exit UDP input thread"}
          }
        end
        private :add_udp_source
      end
    end
  end
end
