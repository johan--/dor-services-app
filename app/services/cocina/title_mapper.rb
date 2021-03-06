# frozen_string_literal: true

module Cocina
  # Maps titles
  class TitleMapper
    def self.build(item)
      new(item).build
    end

    def initialize(item)
      @item = item
    end

    def build
      if item.is_a? Dor::Etd
        item.properties.title.first
      elsif item.label == 'Hydrus'
        # Some hydrus items don't have titles, so using label. See https://github.com/sul-dlss/hydrus/issues/421
        item.label
      else
        item.full_title
      end
    end

    private

    attr_reader :item
  end
end
