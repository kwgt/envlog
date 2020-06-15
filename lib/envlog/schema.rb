#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require "yaml"

module EnvLog
  module Schema
    using DeepFreezer

    class << self
      def read(path)
        return YAML.load_file(path).deep_freeze
      end
    end
  end
end
