#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'socket'

module EnvLog
  module Logger
    module InputSource
      SUPPORT_FORMAT_VERSION = 2

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
          Log.info(tty) {"add UDP input source"}

          sock = UDPSocket.open()
          sock.bind(src[:bind] || "::", src[:port])

          loop {
            begin
              dat = sock.recv(1024)
              tmp = dat.unpack("C6CCs<S<S<S<S<")

              next if tmp[6] != SUPPORT_FORMAT_VERSION

              json = JSON_FORMAT %
                      [tmp[0], tmp[1], tmp[2], tmp[3], tmp[4], tmp[5],
                       tmp[7],
                       tmp[8]  / 100.0,
                       tmp[9]  / 100.0,
                       tmp[10] / 10.0,
                       tmp[11] / 100.0,
                       tmp[12] / 100.0]

              put_data(json)

            rescue Exit
              break
            end
          }

          sock.close
          Log.info(tty) {"exit UDP input thread"}
        end
        private :add_udp_source
      end
    end
  end
end
