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
        def add_tcp_source(src)
          threads << Thread.fork {
            addr = IPAddr.new(src[:bind] || "::")

            if addr.ipv6?
              ep = "TCP([#{addr}]:#{src[:port]})"
            else
              ep = "TCP(#{addr}:#{src[:port]})"
            end

            Log.info(ep) {"add TCP input source"}

            serv = TCPServer.open(addr.to_s, src[:port])

            loop {
              begin
                  sock = serv.accept
                  json = v4data_to_json(sock.readpartial(1024).bytes)
                  Log.debug(ep) {"receive: #{json.dump}"}

                  put_data(json)

              rescue Exit
                break

              rescue NotSupported => e
                p "come"
                Log.debug(ep) {e.message}

              rescue => e
                Log.error(ep) {"error occurred (#{e.message})"}

              ensure
                sock&.close
              end
            }

            serv.close
            Log.info(ep) {"exit TCP input thread"}
          }
        end
      end
    end
  end
end
