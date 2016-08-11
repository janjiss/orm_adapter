require 'rom'
module ROM
  class OrmAdapter < ::OrmAdapter::Base
    # get a list of column names for a given class

    def get!(id)
      klass.get!(id)
    end

    def get(id)
      klass.get(id)
    end

    def find_first(options = {})
      conditions, order = extract_conditions!(options)
      klass.find_first(order: order, conditions: conditions)
    end

    def create!(params)
      klass.create!(params)
    end

    def destroy(params)
      klass.destroy(params)
    end

    def find_all(options = {})
      conditions, order, limit, offset = extract_conditions!(options)
      klass.find_all(:conditions => conditions, :order => order, limit: limit, offset: offset)
    end

    protected

  end
end
