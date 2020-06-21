#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

require 'pathname'

TEST_BASE_DIR = Pathname.new(File.expand_path(__FILE__)).dirname.parent
TEST_DATA_DIR = TEST_BASE_DIR + "data"

PKG_BASE_DIR  = TEST_BASE_DIR.parent
PKG_DATA_DIR  = PKG_BASE_DIR + "data"
PKG_LIB_DIR   = PKG_BASE_DIR + "lib" + "envlog"

require "#{PKG_LIB_DIR}/version"
require "#{PKG_LIB_DIR}/misc"
require "#{PKG_LIB_DIR}/config"
require "#{PKG_LIB_DIR}/schema"
require "#{PKG_LIB_DIR}/log"
