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

    class InvalidData < StandardError
      def initialize(msg, diag)
        super(msg)
        @diag = diag
      end
      attr_reader :diag
    end

    class << self
      def read(path)
        ret  = YAML.load_file(path)

        sch  = JSONSchemer.schema(SCHEMA["CONFIG"])
        diag = sch.validate(ret).to_a
        if not diag.empty?
          raise InvalidData.new("invalid configuration", diag)
        end

        ret.deep_freeze

        return ret

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

      def fetch_path(*key)
        ret = CONFIG.dig(*key)
        return ret && Pathname.new(File.expand_path(ret))
      end
    end
  end
end
