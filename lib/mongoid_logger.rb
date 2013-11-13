# encoding: utf-8

require "mongoid_logger/version"

require "active_support/buffered_logger"
require "mongoid"

module MongoidLogger

  LOG_LEVEL_SYM = [:debug, :info, :warn, :error, :fatal, :unknown]

  LEVEL_NAMES = LOG_LEVEL_SYM.each_with_object({}) do |name, d|
    value = Logger.const_get(name.to_s.upcase)
    d[value] = name.to_s
  end

  autoload :Base         , "mongoid_logger/base"
  autoload :Filter       , "mongoid_logger/filter"
  autoload :LogCollection, "mongoid_logger/log_collection"
end
