# frozen_string_literal: true

# Responsible for retrieving information based on the given Dor::Item.
class ItemQueryService
  # @param [String] id - The id of the item
  # @param [#exists?, #find] item_relation - How we will query some of the related information
  def initialize(id:, item_relation: default_item_relation)
    @id = id
    @item_relation = item_relation
  end

  delegate :allows_modification?, to: :item

  # @raises [RuntimeError] if the item is dark, citation_only, or not modifiable
  def self.find_combinable_item(druid)
    query_service = ItemQueryService.new(id: druid)
    query_service.item do |item|
      raise "Item #{item.pid} is not open for modification" unless query_service.allows_modification?
      raise "Item #{item.pid} is dark" if item.rightsMetadata.dra_object.dark?
      raise "Item #{item.pid} is citation_only" if item.rightsMetadata.dra_object.citation_only?
    end
  end

  def item(&block)
    @item ||= item_relation.find(id)
    return @item unless block_given?

    @item.tap(&block)
  end

  private

  attr_reader :id, :item_relation

  def default_item_relation
    Dor::Item
  end
end
