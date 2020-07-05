#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'pathname'
require 'logger'
require 'optparse'
require 'erb'

TEST_BASE_DIR = Pathname.new(File.expand_path(__FILE__)).dirname.parent
TEST_DATA_DIR = TEST_BASE_DIR + "data"
              
BASE_DIR      = TEST_BASE_DIR.parent
DATA_DIR      = BASE_DIR + "data"
LIB_DIR       = BASE_DIR + "lib" + "envlog"

SCHEMA_FILE   = DATA_DIR + "schema.yml"
CONFIG_FILE   = TEST_DATA_DIR + "config" + "#{ENV["CONFIG"]||"default"}.yml"

require "#{LIB_DIR}/version"
require "#{LIB_DIR}/misc"
require "#{LIB_DIR}/config"
require "#{LIB_DIR}/schema"
require "#{LIB_DIR}/log"

EnvLog::Schema.read(SCHEMA_FILE)
EnvLog::Config.read(CONFIG_FILE)
EnvLog::Log.setup()

module YAMLExtender
  refine YAML do
    class << YAML
      def include(path)
        if File.exist?(path)
          ret = ERB.new(IO.read(path))
        else
          ret = ERB.new(IO.read(TEST_DATA_DIR + "schema" + path))
        end

        return ret.result
      end

      def load_erb(path)
        YAML::load(YAML::include(path))
      end
    end
  end
end

if EnvLog::Config.has?(:database, :sqlite3)
  if not File.exist?(EnvLog::Config.fetch_path(:database, :sqlite3, :path))
    STDERR.print(<<~EOT)
      Please, change to test directory.
    EOT
    exit
  end
end
