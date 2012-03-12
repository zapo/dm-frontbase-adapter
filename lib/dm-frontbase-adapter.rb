require 'dm-core'

class FrontbaseAdapter < ::DataMapper::Adapters::AbstractAdapter
  Inflector = ::DataMapper.const_defined?(:Inflector) ? ::DataMapper::Inflector : ::Extlib::Inflection
end


# add our adapter to datamapper adapter list

::DataMapper::Adapters::FrontbaseAdapter = FrontbaseAdapter
::DataMapper::Adapters.const_added(:FrontbaseAdapter)

LOGGER = DataMapper.logger.dup
LOGGER.progname = "FrontbaseAdapter"

require 'frontbase'
require "dm-frontbase-adapter/adapter"