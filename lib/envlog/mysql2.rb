#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

module Mysql2Extender
  refine Mysql2::Client do
    def get_first_row(query, **opts)
      rows = self.query(query, opts)
      return rows.first
    end

    def get_first_value(query)
      rows = self.query(query, :as => :array)
      return rows.first && rows.first[0]
    end
  end

  refine Mysql2::Statement do
    def get_first_row(*args, **opts)
      rows = self.execute(*args, **opts)
      return rows.first
    end

    def get_first_value(*args)
      rows = self.execute(*args, :as => :array)
      return rows.first && rows.first[0]
    end
  end

  refine String do
    def to_mysql
      #
      # MySQLの文字列リテラルを返すので注意
      #
      return '"' + Mysql2::Client.escape(self) + '"'
    end
  end
end
