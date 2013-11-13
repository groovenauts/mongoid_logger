# encoding: utf-8

require "mongoid_logger/version"

class MongoidLogger < ActiveSupport::BufferedLogger

  class << self
    def collection_names
      @collection_names ||= []
    end
  end


  LOG_LEVEL_SYM = [:debug, :info, :warn, :error, :fatal, :unknown]

  LEVEL_NAMES = LOG_LEVEL_SYM.each_with_object({}) do |name, d|
    value = Logger.const_get(name.to_s.upcase)
    d[value] = name.to_s
  end

  def initialize(path, options={})
    @path = path
    @level = options[:level] || DEBUG
    configure(options)
    super(@path, @level)
  end

  def add(severity, message=nil, progname=nil, &blk)
    if @level <= severity and message.present? and @record.present?
      @record[:messages] ||= []
      @record[:messages] << [severity, message]
    end
    super
  end

  def add_metadata(options={})
    if @record
      options.each_pair do |key, value|
        @record[key] = value
      end
    end
  end

  # override ActiveSupport::BufferedLogger#open_logfile
  def open_logfile(log)
    Logger.new(log).tap do |logger|
      logger.formatter = nil
    end
  end
  private :open_logfile

  def mongoize(controller, options={})
    @record = options.merge({
      :messages => [],
      :request_time => Time.now.getutc,
      :application_name => @application_name,
      :host => Socket.gethostname,
      :pid => Process.pid,
    })
    st = Time.now
    yield
    ed = Time.now
    @record["runtime"] = (ed - st).to_f
    @record["status"] = controller.response.status
  rescue Exception
    if st
      @record["runtime"] = (Time.now - st).to_f
    end
    @record["status"] = 500
    add(3, $!.message + "\n  " + $!.backtrace.join("\n  ")) #rescue nil
    raise
  ensure
    begin
      insert_document(@record)
    rescue
    end
  end

  def create_collection(name)
    @session.command(create: name, capped: true, size: @db_configuration["capsize"] || 64.megabyte)
  rescue Exception => e
    if e.message =~ /collection already exists/
      internal_log(:warn, "Ignore #{name} creation failure. See following message of #{e.class.name}:\n" << e.message)
    else
      raise e
    end
  end

  def confirm_collection
    mongo_collection_name_array.each do |name|
      unless @session.collections.find{|col| col.name == name }
        create_collection(name)
      end
    end
  end

  def reset_collection
    mongo_collection_name_array.each do |name|
      @session.command(drop: name)
      create_collection(name)
    end
  end

  attr_reader :mongo_collection_names

  def mongo_collection_name_array
    (@mongo_collection_names.values + [@mongo_collection_names.default]).compact.uniq
  end

  private

  def configure(options={})
    @db_configuration = {
      "capsize" => 512.megabytes,
    }.merge(resolve_config)
    base_name = options[:collection_name] || @db_configuration["log_collection"]
    @mongo_collection_names = (options[:isolated_methods] || []).each_with_object({}){|name,d | d[name] = base_name.sub(/_logs\Z/){ "_#{name}_logs" }  }
    @mongo_collection_names.default = base_name

    @application_name = @db_configuration["application_name"]
    @session = Mongoid.default_session.with(safe: true)
    confirm_collection

    @mongo_collections = @mongo_collection_names.each_with_object({}){|(k, col_name), d| d[k] = @session[col_name] }
    @mongo_collections.default = @session[ @mongo_collection_names.default ]

    @ignore_block = options[:ignore]
  end

  def resolve_config
    config = {}
    config_file = Rails.root.join("config", "mongoid.yml")
    if config_file.file?
      env = YAML.load(ERB.new(config_file.read).result)[Rails.env]
      sessions = env["sessions"] if env
      if sessions
        if sessions["mongoid_logger"]
          config = sessions["mongoid_logger"]
        elsif sessions["default"]
          config = sessions["default"]
        end
      end
    end
    return {
      "log_collection" => "#{Rails.env}_logs",
      "application_name" => Rails.application.class.to_s.split("::").first,
    }.update(config)
  end

  def insert_document(doc)
    doc[:level] = doc[:messages].map(&:first).min || 0
    return if @ignore_block && @ignore_block.call(doc)
    col = @mongo_collections[ doc[:request_method].downcase.to_sym ]
    col.insert(doc)
  end

  def internal_log(log_level, msg)
    $stderr.puts("#{log_level} #{msg}")
  end

  # ApplicationController に include して around_filter でログ挿入するためのモジュール
  module Filter
    def self.included(klass)
      klass.class_eval { around_filter :enable_mongoid_logger }
    end

    def enable_mongoid_logger
      return yield unless Rails.logger.respond_to?(:mongoize)

      f_params = case
                 when request.respond_to?(:filtered_parameters)
                   request.filtered_parameters
                 when respond_to?(:filter_parameters)
                   filter_parameters(params)
                 else
                   params
                 end
      # controllerのloggerに対して処理を行います
      logger.mongoize(self, {
        :request_method => request.request_method,
        :path       => request.path,
        :url        => request.url,
        :params     => f_params,
        :remote_ip  => request.remote_ip,
      }) { yield }
    end
  end

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
