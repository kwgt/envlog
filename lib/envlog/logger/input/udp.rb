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
      SUPPORTED_FORMAT_VERSION = 3

      JSON_FORMAT = <<~EOT.gsub(/\s/, "")
        {
          "addr":"%02x:%02x:%02x:%02x:%02x:%02x",
          "seq":%d,
          "temp":%4.1f,
          "hum":%4.1f,
          "a/p":%d,
          "rssi":null,
          "vbat":%4.2f,
          "vbus":%4.2f
        }
      EOT

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
                dat = sock.recv(1024)
                tmp = dat.unpack("CCC6s<S<S<S<S<")

                next if tmp[0] != SUPPORTED_FORMAT_VERSION

                json = JSON_FORMAT %
                        [tmp[2], tmp[3], tmp[4], tmp[5], tmp[6], tmp[7],
                         tmp[1],
                         tmp[8]  / 100.0,
                         tmp[9]  / 100.0,
                         tmp[10] / 10.0,
                         tmp[11] / 100.0,
                         tmp[12] / 100.0]

                Log.debug(ep) {"receive: #{json.dump}"}

                put_data(json)

              rescue Exit
                break
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
