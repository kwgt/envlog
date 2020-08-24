#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'yaml'
require 'json_schemer'

module EnvLog
  module Config
    using DeepFreezer
    using KeyConverter

    class InvalidValue < StandardError; end

    class FormatError < StandardError
      def initialize(msg, diag)
        super(msg)
        @diag = diag
      end
      attr_reader :diag
    end

    class << self
      def check_graph_config(data)
        (data[:graph] ||= {}).instance_eval {
          (self[:range] ||= {}).instance_eval {
            self[:temp]  ||= {:min => 5, :max => 40}
            self[:hum]   ||= {:min => 30, :max => 90}
            self[:"a/p"] ||= {:min => 995, :max => 1020}
          }
        }

        tmp = data.dig(:graph, :range, :temp)

        if tmp[:min] >= tmp[:max]
          raise InvalidValue.new(<<~EOT)
            wrong relationship between min and max (graph.range.temp).
          EOT
        end

        tmp = data.dig(:graph, :range, :hum)

        if tmp[:min] >= tmp[:max]
          raise InvalidValue.new(<<~EOT)
            wrong relationship between min and max (graph.range.hum).
          EOT
        end


        tmp = data.dig(:graph, :range, :"a/p")

        if tmp[:min] >= tmp[:max]
          raise InvalidValue.new(<<~EOT)
            wrong relationship between min and max (graph.range.a/p).
          EOT
        end
      end
      private :check_graph_config

      def read(path)
        data = YAML.load_file(path)

        diag = Schema.validate(:CONFIG, data)
        if not diag.empty?
          raise FormatError.new("invalid configuration", diag)
        end

        data.symbolize_keys!

        check_graph_config(data)

        data.deep_freeze

        @config = data

      rescue YAML::SyntaxError => e
        STDERR.print("#{e.message}\n")
        exit 1

      rescue FormatError => e
        STDERR.print("Configuration format error.\n")
        e.diag.each.with_index { |info, i|
         STDERR.print(<<~EOT)
           error ##{i}
             value: #{info["data"]}
             data-path: #{info["data_pointer"]}
         EOT
        }
        exit 1

      rescue InvalidValue => e
        STDERR.print("Configuration data error.\n")
        STDERR.print(e.message)
        exit 1
      end

      def [](key)
        raise("configuration data not read yet") if not @config
        return @config[key]
      end

      def dig(*keys)
        raise("configuration data not read yet") if not @config
        return @config.dig(*keys)
      end

      def fetch_path(*key)
        raise("configuration data not read yet") if not @config
        ret = @config.dig(*key)
        return ret && Pathname.new(File.expand_path(ret))
      end

      def has?(*keys)
        raise("configuration data not read yet") if not @config
        return @config.dig(*keys).!.!
      end
    end
  end
end
