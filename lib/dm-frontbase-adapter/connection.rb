class FrontbaseAdapter < ::DataMapper::Adapters::AbstractAdapter
  
  # Connection wrapper

  class Connection
    
    def initialize(options)
      default = {
        :host       => 'localhost',
        :port       => -1,
        :user       => '',
        :password   => '',
        :dbpassword => '',
        :database   => '',
      }
      
      @options = default.merge(options)
      connection
    end
    
    def connection
      unless @connection
        LOGGER.debug "Opening connection..."
        @connection = FBSQL_Connect.new(
          @options[:host],
          @options[:port], 
          @options[:database], 
          @options[:user], 
          @options[:password], 
          @options[:dbpassword]
        )
        @connection.input_charset  = encoding_map['UTF-8']
        @connection.output_charset = encoding_map['ISO-8859-1']
      end
      
      @connection
    end
    
    def query str
      LOGGER.debug str
      connection.query str
    end
    
    def encoding_map
      {
        'ISO-8859-1' => FBSQL_Connect::FBC_ISO8859_1,
        'UTF-8'      => FBSQL_Connect::FBC_UTF_8
      }
    end
    
    def describe(table)
      sql = %[SELECT T3."COLUMN_NAME" AS NAME, T4."DATA_TYPE" FROM 
        INFORMATION_SCHEMA.CATALOGS T0, 
        INFORMATION_SCHEMA.SCHEMATA T1, 
        INFORMATION_SCHEMA.TABLES T2, 
        INFORMATION_SCHEMA.COLUMNS T3,
        INFORMATION_SCHEMA.DATA_TYPE_DESCRIPTOR T4 

        WHERE 
          T0."CATALOG_PK" = T1."CATALOG_PK" AND 
          T1."SCHEMA_PK" = T2."SCHEMA_PK" AND 
          T2."TABLE_PK" = T3."TABLE_PK" AND 
          T3."COLUMN_PK" = T4."COLUMN_NAME_PK" AND 
          T1."SCHEMA_NAME" LIKE CURRENT_SCHEMA AND
          T2."TABLE_NAME" LIKE '#{table}';]
      connection.query(sql)
    end
    
    def close
      LOGGER.debug "Closing connection..."
      connection.close
      @connection = nil
    end

  end
  
end