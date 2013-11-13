# -*- coding: utf-8 -*-
require 'mongoid_logger'

module MongoidLogger

  # ログコレクションのためのモジュール
  module LogCollection
    def self.included(klass)
      klass.class_eval do
        include Mongoid::Document
        field :request_time,     :type => ActiveSupport::TimeWithZone
        field :application_name, :type => String
        field :level,            :type => Integer
        field :host,             :type => String
        field :pid,              :type => Integer
        field :request_method,   :type => String
        field :path,             :type => String
        field :url,              :type => String
        field :params,           :type => Object
        field :remote_ip,        :type => String
        field :messages,         :type => Array
        field :runtime,          :type => Float
        field :status,           :type => Integer

        def level_name
          LOG_LEVEL_SYM[level]
        end

      end
    end
  end

end
