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

    class InvalidData < StandardError
      def initialize(msg, diag)
        super(msg)
        @diag = diag
      end
      attr_reader :diag
    end

    class << self
      def read(path)
        data = YAML.load_file(path)

        diag = Schema.validate(:CONFIG, data)
        if not diag.empty?
          raise InvalidData.new("invalid configuration", diag)
        end

        data.symbolize_keys!
        data.deep_freeze

        @config = data

      rescue YAML::SyntaxError => e
        STDERR.print("#{e.message}\n")
        exit 1

      rescue InvalidData => e
        STDERR.print(e.message)
        e.diag.each.with_index { |info, i|
         STDERR.print(<<~EOT)
           error ##{i}
             value: #{info["data"]}
             data-path: #{info["data_pointer"]}
         EOT
        }
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
