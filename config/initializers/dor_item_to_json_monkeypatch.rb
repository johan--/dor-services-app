module Dor
  class Item
    # TODO: figure out how to handle this for reals
    def to_json
      hash = JSON.parse(super)
      hash[:label] = label
      hash.to_json
    end
  end
end
