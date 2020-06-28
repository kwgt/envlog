#! /usr/bin/env ruby
# coding: utf-8

#
# Environemnt data logger 
#
#   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
#

module DeepFreezer
  refine Hash do
    def deep_freeze
      self.each_pair { |k, v|
        if k.kind_of?(Hash) or k.kind_of?(Array)
          k.deep_freeze
        else
          k.freeze
        end

        if v.kind_of?(Hash) or v.kind_of?(Array)
          v.deep_freeze
        else
          v.freeze
        end
      }

      return self
    end

  end

  refine Array do
    def deep_freeze
      self.each { |v|
        if v.kind_of?(Hash) or v.kind_of?(Array)
          v.deep_freeze
        else
          v.freeze
        end
      }

      return self
    end
  end
end

module KeyConverter
  refine Hash do
    def stringify_keys
      ret = {}

      self.each_pair { |k, v|
        k = k.to_s if k.kind_of?(Symbol)
        v = v.stringify_keys if v.kind_of?(Hash) or v.kind_of?(Array)

        ret[k] = v
      }

      return ret
    end

    def stringify_keys!
      self.keys.each { |k|
        self[k.to_sym] = self.delete(k) if k.kind_of?(Symbol)
      }

      self.each_value { |v|
        v.stringify_keys! if v.kind_of?(Hash) or v.kind_of?(Array)
      }

      return self
    end

    def symbolize_keys
      ret = {}

      self.each_pair { |k, v|
        if k.kind_of?(String)
          k = k.to_sym
          ret[k] = v
        end

        v = v.symbolize_keys if v.kind_of?(Hash) or v.kind_of?(Array)

        ret[k] = v
      }

      return ret
    end

    def symbolize_keys!
      self.keys.each { |k|
        self[k.to_sym] = self.delete(k) if k.kind_of?(String)
      }

      self.each_value { |v|
        v.symbolize_keys! if v.kind_of?(Hash) or v.kind_of?(Array)
      }

      return self
    end

  end

  refine Array do
    def stringify_keys
      ret = []

      self.each { |v|
        v = v.stringify_keys if v.kind_of?(Hash) or v.kind_of?(Array)
        ret << v
      }

      return ret
    end

    def stringify_keys!
      self.each { |v|
        v.stringify_keys! if v.kind_of?(Hash) or v.kind_of?(Array)
      }

      return self
    end

    def symbolize_keys
      ret = []

      self.each { |v|
        v = v.symbolize_keys if v.kind_of?(Hash) or v.kind_of?(Array)
        ret << v
      }

      return ret
    end

    def symbolize_keys!
      self.each { |v|
        v.symbolize_keys! if v.kind_of?(Hash) or v.kind_of?(Array)
      }

      return self
    end
  end
end

module TimeStringFormatChanger
  refine Time do
    # SQLite3の返すフォーマットに合わせる
    def to_s
      return self.strftime("%Y-%m-%d %H:%M:%S")
    end
  end
end
