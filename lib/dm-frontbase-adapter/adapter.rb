require 'dm-frontbase-adapter/connection'
require 'dm-frontbase-adapter/sql'


class FrontbaseAdapter < ::DataMapper::Adapters::AbstractAdapter
  
  include SQL

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

    repository    = query.repository
    model_name    = query.model.name
    properties    = query.fields
    conditions    = query.conditions.map {|c| conditions_statement(c, repository)}.compact.join(") AND (")

    storage_name = model_name

    # get model storage name
    if query.model.storage_names.has_key? repository.name.to_sym
      if !query.model.storage_names[repository.name.to_sym].nil?
        storage_name = query.model.storage_names[repository.name.to_sym]
      end
    end
    
    statement =  "SELECT #{columns_statements(properties, repository)}"
    statement << " FROM #{quote_name(storage_name)}"
    statement << " WHERE (#{conditions})" unless conditions.empty?
    statement << " ORDER BY #{order(query.order[0])}" unless query.order.nil? or query.order.empty?
    statement << ";"
    
    if query.limit || (query.limit && query.offset > 0)

      replacement = "SELECT TOP(" 
      replacement << "#{query.offset.to_i}," if query.limit && query.offset > 0
      replacement << "#{query.limit.to_i}"   if query.limit 
      replacement << ")"

      statement.gsub!('SELECT', replacement)
    end
    
    log statement
    
    records = with_connection { |connection|
      response_to_a(connection.query(statement), properties)
    }
    
    query.model.load(records, query)
  end
  
  def response_to_a response, props = nil
    columns = response.columns
    result = response.result 

    result.inject([]) do |arr, record|
      
      record = Hash[*columns.zip(record).flatten].inject({}) do |hash, (column, value)| 
        if props && (prop = props.find {|prop| prop.field.to_sym == column.to_sym })
          
          case
          when prop.is_a?(::DataMapper::Property::Boolean)
            value = case value
            when 1.0, 1, true, "true"
              true
            else
              false
            end
          when prop.kind_of?(::DataMapper::Property::String)
            value = value.to_s.force_encoding("ISO-8859-1").encode("UTF-8")
          end
          
          value = prop.typecast(value)
          
        elsif value.kind_of? String
          value = value.to_s.force_encoding("ISO-8859-1").encode("UTF-8")
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
      response = connection.describe storage_name
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