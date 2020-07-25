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
          fd_list = -> (a) {a.map {|v| v.to_i}}
          reject  = -> (s) {s.close; set.delete(s)}

          threads << Thread.fork {
            begin
              addr = IPAddr.new(src[:bind] || "::")

              if addr.ipv6?
                ep = "TCP([#{addr}]:#{src[:port]})"
              else
                ep = "TCP(#{addr}:#{src[:port]})"
              end

              Log.info(ep) {"add TCP input source"}

              serv = TCPServer.open(addr.to_s, src[:port])
              set  = [serv]

              loop {
                Log.debug(ep) {"select #{fd_list.(set)}"}
                rdy = IO.select(set, [], set, 60)

                #
                # when timeout cleanning socket set,
                # and goto next iteration.
                #
                if not rdy
                  Log.debug(ep) {"timedout #{fd_list.(set)}"}
                  set.each {|sock| sock.close if sock != serv}
                  set.reject! {|sock| sock.closed?}
                  next
                end

                Log.debug(ep) {
                  rd = fd_list.(rdy[0])
                  wr = fd_list.(rdy[1])
                  ex = fd_list.(rdy[2])
                  "resume #{rd.inspect} #{wr.inspect} #{ex.inspect}"
                }

                #
                # for readable sockets
                #
                rdy[0].each { |sock|
                  if sock == serv
                    set << serv.accept
                    Log.debug("accepted #{set.last.to_i}")
                  else
                    if sock.eof?
                      Log.debug("close #{sock.to_i}")
                      reject.(sock)

                    else
                      begin
                        data = unpack_v4_data(sock.readpartial(128).bytes)
                        Log.debug(ep) {"receive: #{data.inspect}"}

                        put_data(data)

                      rescue NotSupported => e
                        Log.error(ep) {e.message}

                      rescue InvalidData => e
                        Log.error(ep) {"rejected invalid data #{e.data}"}

                      rescue => e
                        Log.error(ep) {"error occurred (#{e.message})"}
                      end
                    end
                  end
                }

                #
                # for exception occurred sockets
                #
                rdy[2].each {|sock|
                  Log.debug("excepted #{sock.to_i}")
                  reject.(sock)
                }
              }
                  
            rescue Exit
              Log.info(ep) {"exit TCP input thread"}

            rescue => e
              Log.error(ep) {"error occurred (#{e.message})"}
              pp e.backtrace

            ensure
              set&.each {|sock| sock.close} if defined?(set)
            end
          }
        end
      end
    end
  end
end
