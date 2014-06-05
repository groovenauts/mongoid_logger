# -*- coding: utf-8 -*-
require 'mongoid_logger'

module MongoidLogger

  # ApplicationController に include して around_filter でログ挿入するためのモジュール
  module Filter
    def self.included(klass)
      klass.class_eval { around_filter :enable_mongoid_logger }
    end

    def enable_mongoid_logger
      return yield unless logger.respond_to?(:enable_mongoid_logging)

      f_params = case
                 when request.respond_to?(:filtered_parameters)
                   request.filtered_parameters
                 when respond_to?(:filter_parameters)
                   filter_parameters(params)
                 else
                   params
                 end
      # controllerのloggerに対して処理を行います
      logger.enable_mongoid_logging(self, {
        :request_method => request.request_method,
        :path       => request.path,
        :url        => request.url,
        :params     => f_params,
        :remote_ip  => request.remote_ip,
      }) { yield }
    end
  end

end
