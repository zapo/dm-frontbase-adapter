require 'dm-frontbase-adapter/connection'
require 'dm-frontbase-adapter/sql_query'


class FrontbaseAdapter < ::DataMapper::Adapters::AbstractAdapter
  
  # cache data per operation accessor
  attr_accessor :data
  
  # frontbase operations accessor
  attr_accessor :models_operations

  def field_naming_convention
     proc {|property| property.name.to_s }
  end
  
  def resource_naming_convention
    proc {|resource| resource.to_s }
  end
  
  def initialize(name, options)

    # store our options in a hash :sym => value
    @options = options.inject({}) {|memo, (k,v)| memo[k.to_sym] = v; memo}
    @options[:encoding] ||= 'iso-8859-1'
    
    # initialize abstract adapter
    super(name, @options)
  end
  
  def log msg
    DataMapper.logger.info "FrontbaseAdapter: #{msg}"
  end

  def connection
    @connection ||= FrontbaseAdapter::Connection.new(@options)
  end

  def with_connection &block
    block.call(connection) if block
  rescue
    raise $!
  ensure
    connection.close
  end

  # Simple read method that take a DataMapper::Query object that represent the query
  # Returns a filtered data hash built from the query model operation returned xml
  def read(query)

    properties = query.fields
    
    statement = SQLQuery.new(query, :select).to_s
    
    log statement
    
    records = with_connection { |connection|
      response_to_a(connection.query(statement), properties)
    }
    
    query.filter_records(records)
  end
  
  def response_to_a response, props = nil
    columns = response.columns
    result = response.result 

    result.inject([]) do |arr, record|
      
      record = Hash[*columns.zip(record).flatten].inject({}) do |hash, (column, value)| 
        if props && (prop = props.find {|prop| prop.field.to_sym == column.to_sym })
          
          case
          when prop.is_a?(::DataMapper::Property::Boolean)
            value = case
            when [1.0, 1, true, "true"].include?(value)
              true
            else
              false
            end
          when prop.kind_of?(::DataMapper::Property::String)
            value = value.to_s.force_encoding(@options[:encoding]).encode("UTF-8")
          end
          
          value = prop.typecast(value)
          
        elsif value.kind_of? String
          value = value.to_s.force_encoding(@options[:encoding]).encode("UTF-8")
        end
        
        hash[column] = value
        hash
      end
      arr << record
      arr
    end
  end
  
  def describe storage_name
    with_connection do |connection|
      connection.describe storage_name
    end
  end
  
  def show_tables
    with_connection do |connection|
      
      stmt = 'SELECT * FROM INFORMATION_SCHEMA.SCHEMATA T0, INFORMATION_SCHEMA.TABLES T1 WHERE T0."SCHEMA_PK" = T1."SCHEMA_PK";'
      log stmt

      records = response_to_a(connection.query(stmt))
      records.find_all {|record| record[:SCHEMA_NAME] != 'INFORMATION SCHEMA' && record[:TABLE_TYPE] == 'BASE_TABLE'}.map {|record| record[:TABLE_NAME]}
    end
  end
end