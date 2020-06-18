#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require "yaml"
require "json_schemer"

module EnvLog
  module Schema
    using DeepFreezer

    class << self
      def read(path)
        data = YAML.load_file(path)

        data.keys.each {|key| data[key.to_sym] = data.delete(key)}
        data.deep_freeze

        @schema = data
      end

      def [](key)
        raise("schema data not read yet") if not @schema

        return @schema[key]
      end

      def validate(key, data)
        raise("schema data not read yet") if not @schema

        sch = JSONSchemer.schema(@schema[key])
        return sch.validate(data).to_a
      end
    end
  end
end
