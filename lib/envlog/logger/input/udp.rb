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
      SUPPORTED_FORMAT_VERSION = 4

      module LocalArrayExtender
        refine Array do
          def shift_u16
            lo, hi = self.shift(2)

            return (((hi << 8) & 0xff00) | ((lo << 0) & 0x00ff))
          end
        end
      end

      class << self
        using LocalArrayExtender

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
                src  = sock.recv(1024).bytes

                next if src.shift != SUPPORTED_FORMAT_VERSION

                json = "{"

                json << '"seq":%s' % src.shift
                json << ',"addr":"%02x:%02x:%02x:%02x:%02x:%02x"' % src.shift(6)

                flg = src.shift_u16

                if flg.anybits?(0x0001)
                  json << ',"temp":%.1f' % (src.shift_u16 / 100.0)
                end

                if flg.anybits?(0x0002)
                  json << ',"hum":%.1f' % (src.shift_u16 / 100.0)
                end

                if flg.anybits?(0x0004)
                  json << ',"a/p":%d' % (src.shift_u16)
                end

                if flg.anybits?(0x0008)
                  json << ',"vbat":%.2f' % (src.shift_u16 / 100.0)
                end

                if flg.anybits?(0x0010)
                  json << ',"vbus":%.2f' % (src.shift_u16 / 100.0)
                end


                json << "}"

                Log.debug(ep) {"receive: #{json.dump}"}

                put_data(json)

              rescue Exit
                break

              rescue => e
                Log.error(ep) {"error occurred (#{e.message})"}
                pp e.backtrace
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
