#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'time'

module EnvLog
  module Logger
    module InputSource
      MONITOR_INTERVAL         = 60
      STALL_THRESHOLD          = 300
      SUPPORTED_FORMAT_VERSION = 4

      module LocalArrayExtender
        refine Array do
          def shift_u16
            lo, hi = self.shift(2)

            return (((hi << 8) & 0xff00) | ((lo << 0) & 0x00ff))
          end
        end
      end

      class Exit < Exception; end

      class ParseError < StandardError
        def initialize(json)
          super("JSON parse error")
          @json = json
        end
        attr_reader :json
      end

      class InvalidData < StandardError
        def initialize(data)
          super("Validation error")
          @data = data
        end
        attr_reader :data
      end

      class NotSupported < StandardError; end

      class << self
        using TimeStringFormatChanger
        using LocalArrayExtender

        def queue
          return @queue  ||= Thread::Queue.new
        end

        def threads
          return @thread ||= []
        end
        private :threads

        def battery_dead(id, addr)
          Log.warn("input") {
            "sensor #{id} (#{addr}) external battery is dead."
          }
        end

        def battery_recover(id, addr)
          Log.info("input") {
            "sensor #{id} (#{addr}) external battery is recovered."
          }
        end

        def unpack_v4_data(src)
          ver = src.shift
          if ver != SUPPORTED_FORMAT_VERSION
            raise NotSupported.new("not support format version #{ver}")
          end

          ret = {
            "seq"  =>  src.shift,
            "addr" => "%02x:%02x:%02x:%02x:%02x:%02x" % src.shift(6)
          }

          flg = src.shift_u16

          if flg.anybits?(0x0001)
            ret["temp"] = src.shift_u16 / 100.0
          end

          if flg.anybits?(0x0002)
            ret["hum"]  = src.shift_u16 / 100.0
          end

          if flg.anybits?(0x0004)
            ret["a/p"]  = (src.shift_u16 / 10.0).round
          end

          if flg.anybits?(0x0008)
            ret["vbat"] = src.shift_u16 / 100.0
          end

          if flg.anybits?(0x0010)
            ret["vbus"] = src.shift_u16 / 100.0
          end

          return ret
        end

        def put_data(data)
          if not Schema.valid?(:INPUT_DATA, data)
            raise InvalidData.new(data)
          end

          # データベースへの登録に時間がかかり、処理が遅延する場合が
          # あったのでスレッドを分離し非同期処理に変更した。
          # 登録処理本体はentry_threadで行なっている。
          queue << Time.now.to_s
          queue << data
        end
        private :put_data

        def recording?(info)
          return %w[NORMAL DEAD-BATTERY].include?(info[:state])
        end
        private :recording?

        def timedout?(info, ts)
          return (ts - Time.parse(info[:mtime])) > STALL_THRESHOLD
        end
        private :timedout?

        def stalled?(info, ts)
          return recording?(info) && timedout?(info, ts)
        end
        private :stalled?

        def monitor_thread
          Log.info("input") {"start moinitor thread"}

          loop {
            begin
              sleep(MONITOR_INTERVAL)

              now = Time.now

              DBA.poll_sensor.each { |id, info|
                DBA.set_stall(id) if stalled?(info, now)
              }

            rescue Exit
              break
            end
          }

          Log.info("input") {"exit moinitor thread"}
        end
        private :monitor_thread

        def entry_thread
          Log.info("input") {"start data entry thread"}

          loop {
            begin
              ts   = queue.deq
              data = queue.deq
              info = DBA.get_sensor_info(data["addr"])

              if info
                case info[:state]
                when "READY", "NORMAL", "STALL"
                  case info[:powsrc]
                  when "BATTERY"
                    if data["vbus"] < 4.0
                      battery_dead(info[:id], data["addr"])
                      state = "DEAD-BATTERY"
                    else
                      state = "NORMAL"
                    end

                  else
                    state = "NORMAL"
                  end

                  DBA.put_data(info[:id], ts, data, state)

                when "DEAD-BATTERY"
                  if data["vbus"] >= 4.0
                    battery_recover(info[:id], data["addr"])
                    state = "NORMAL"

                  else
                    state = "DEAD-BATTERY"
                  end

                  DBA.put_data(info[:id], ts, data, state)

                when "UNKNOWN"
                  DBA.update_timestamp(info[:id], ts)

                when "PAUSE"
                  # ignore
                end

              else
                Log.error("input") {"found unknown device (#{data["addr"]})"}
                DBA.regist_unknown(data["addr"], ts)
              end

            rescue Exit
              break
            end
          }

          Log.info("input") {"exit data entry thread"}
        end
        private :entry_thread

        def add_source(src)
          case src[:type]
          when "serial"
            add_serial_source(src)

          when "udp"
            add_udp_source(src)

          when "tcp"
            add_tcp_source(src)

          else
            raise("unknown input source(#{src["type"]})")
          end
        end

        def run
          threads << Thread.fork {monitor_thread()}
          threads << Thread.fork {entry_thread()}
          threads.each {|thread| thread.join}
        end

        def stop
          threads.each {|thread| thread.raise(Exit)}
        end
      end
    end
  end
end

require_relative "input/serial"
require_relative "input/udp"
require_relative "input/tcp"
