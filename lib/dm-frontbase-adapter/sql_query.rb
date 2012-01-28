class FrontbaseAdapter
  class SQLQuery
    
    include DataMapper::Query::Conditions
    
    attr_reader :conditions, :order, :type, :from, :columns
    
    def initialize(query, type)
      @type       = type
      @query      = query
      
      setup_statement
    end
    
    def setup_statement
      @conditions = (@query.conditions && !@query.conditions.empty?) ?
        conditions_statement(@query.conditions) : ''
      
      @order      = (@query.order      && !@query.order.empty?) ?
        order_statement(@query.order) : ''
      
      @columns    = columns_statement @query.fields
      
      @from       = quote_name(@query.model.storage_name(@query.repository))
    end
    
    def order_statement orders
      orders.map {|o| "#{o.target.field} #{o.operator.to_s.upcase}" }.join(', ')
    end
    
    def columns_statement properties
      properties.map {|property| property_to_column_name(property) }.join(', ')
    end
    
    def to_s
      
      statement = ''
      
      if @type == :select
        statement <<  "SELECT   #{columns}"
        statement << " FROM     #{from}"
        statement << " WHERE    #{conditions}"  unless conditions.empty?
        statement << " ORDER BY #{order}"       unless order.empty?
        statement << ";"

        if @query.limit || (@query.limit && @query.offset > 0)

          replacement = "SELECT TOP(" 
          replacement << "#{@query.offset.to_i}," if @query.limit && @query.offset > 0
          replacement << "#{@query.limit.to_i}"   if @query.limit 
          replacement << ")"

          statement.gsub!('SELECT', replacement)
        end
      end

      statement
    end
    
    def conditions_statement(conditions)
      case conditions
        when AbstractOperation  then  operation_statement(conditions)
        when AbstractComparison then comparison_statement(conditions)
      end
    end
    
    def operation_statement(operation)
      case operation
        when NotOperation then "NOT(#{conditions_statement(operation.first)})"
        when AndOperation then "(#{operation.map {|op| conditions_statement(op) }.join(' AND ')})"
        when OrOperation  then "(#{operation.map {|op| conditions_statement(op) }.join(' OR ')})"
      end
    end

    def comparison_statement(comparison)
      
      return conditions_statement(comparison.foreign_key_mapping) if comparison.relationship?
      
      value   = comparison.value
      subject = property_to_column_name comparison.subject

      operator = case comparison
        when EqualToComparison              then '='
        when GreaterThanComparison          then '>'
        when LessThanComparison             then '<'
        when GreaterThanOrEqualToComparison then '>='
        when LessThanOrEqualToComparison    then '<='
        when LikeComparison                 then 'LIKE'
        when InclusionComparison            then include_operator(value)
      end

      "#{subject} #{operator} #{quote_value(value, comparison.subject)}"
    end
    
    def include_operator(value)
      case operand
      when Array then 'IN'
      when Range then 'BETWEEN'
      end
    end

    def property_to_column_name(prop)
      case prop
      when DataMapper::Property
        quote_name(prop.field)
      when DataMapper::Query::Path
        rels = prop.relationships
        names = rels.map {|r| storage_name(r, @query.repository) }.join(".")
        "#{names}.#{quote_name(prop.field)}"
      end
    end
    
    def quote_name(name)
      "\"#{name.gsub('"', '""')}\""
    end

    def storage_name(rel, repository)
      rel.parent_model.storage_name(repository.name)
    end


    def quote_value(value, property)
      if property.kind_of? DataMapper::Property::Boolean
        return value == DataMapper::Property::Boolean::TRUE ? 'TRUE' : 'FALSE'
      end

      case
      when value.kind_of?(Array)
        "(#{value.map {|v| quote_value(v, property)}.join(", ")})"
      when value.kind_of?(NilClass)
        "NULL"
      when value.kind_of?(String)
        "'#{value.to_s.gsub(/'/, "\\'").gsub(/\\/, %{\\\\})}'"
      else
        value.to_s
      end
    end
  end
end
