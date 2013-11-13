require 'mongoid_logger'

module MongoidLogger

class Base < ActiveSupport::BufferedLogger

  class << self
    def collection_names
      @collection_names ||= []
    end
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
    @record["status"] = controller ? controller.response.status : 200
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
    {}
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

end

end
