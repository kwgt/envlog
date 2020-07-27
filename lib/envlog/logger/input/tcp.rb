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
            begin
              addr = IPAddr.new(src[:bind] || "::")

              if addr.ipv6?
                ep = "TCP([#{addr}]:#{src[:port]})"
              else
                ep = "TCP(#{addr}:#{src[:port]})"
              end

              Log.info(ep) {"add TCP input source"}

              serv    = TCPServer.open(addr.to_s, src[:port])
              set     = [serv]
              map     = {}
              fd_list = -> (a) {a.map {|v| v.to_i}}
              reject  = -> (s) {s.close; set.delete(s); map.delete(s)}

              loop {
                Log.debug(ep) {"select #{fd_list.(set)}"}
                rdy = IO.select(set, [], set, 60)

                if rdy
                  Log.debug(ep) {
                    rd = fd_list.(rdy[0])
                    wr = fd_list.(rdy[1])
                    ex = fd_list.(rdy[2])
                    "resume #{rd} #{wr} #{ex}"
                  }

                  #
                  # for readable sockets
                  #
                  rdy[0].each { |sock|
                    if sock == serv
                      sock = serv.accept
                      set << sock
                      map[sock] = Time.now
                      Log.debug(ep) {"accepted #{set.last.to_i}"}

                    else
                      begin
                        src  = sock.readpartial(128).bytes
                        data = unpack_v4_data(src)
                        Log.debug(ep) {"receive #{sock.to_i} #{data}"}

                        put_data(data)

                      rescue NotSupported => e
                        Log.error(ep) {e.message}

                      rescue InvalidData => e
                        Log.error(ep) {"rejected invalid data #{e.data}"}

                      rescue => e
                        Log.error(ep) {"error occurred (#{e.message})"}

                      ensure
                        reject.(sock)
                      end
                    end
                  }

                  #
                  # for exception occurred sockets
                  #
                  rdy[2].each {|sock|
                    Log.debug(ep) {"excepted #{sock.to_i}"}
                    reject.(sock)
                  }
                end

                #
                # cleaning
                #
                now = Time.now
                map.keys.each { |sock|
                  if now - map[sock] > 10
                    Log.debug(ep) {"force close #{sock.to_i}"}
                    reject.(sock)
                  end
                }
              }
                    
            rescue Exit
              Log.info(ep) {"exit TCP input thread"}

            rescue => e
              Log.error(ep) {"error occurred (#{e.message})"}

            ensure
              set&.each {|sock| sock.close} if defined?(set)
            end
          }
        end
      end
    end
  end
end
