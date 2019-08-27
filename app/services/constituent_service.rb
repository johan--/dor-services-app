# frozen_string_literal: true

# Adds a constituent relationship between a parent work and child works
# by taking the followin actions:
#  1. altering the contentMD of the parent
#  2. add isConstituentOf assertions to the RELS-EXT of the children
#  3. saving the parent and the children
class ConstituentService
  # @param [String] parent_druid the identifier of the parent object
  def initialize(parent_druid:)
    @parent_druid = parent_druid
  end

  # This resets the contentMetadataDS of the parent and then adds the child resources.
  # Typically this is only called one time (with a list of all the pids) because
  # subsequent calls will erase the previous changes.
  # @param [Array<String>] child_druids the identifiers of the child objects
  def add(child_druids:)
    ResetContentMetadataService.new(druid: parent_druid).reset

    child_druids.each do |child_druid|
      add_constituent(child_druid: child_druid)
    end
    parent.save!
  end

  private

  attr_reader :parent_druid

  def add_constituent(child_druid:)
    child = ItemQueryService.find_modifiable_item(child_druid)
    child.contentMetadata.ng_xml.search('//resource').each do |resource|
      parent.contentMetadata.add_virtual_resource(child.id, resource)
    end
    child.add_relationship :is_constituent_of, parent
    child.save!
  end

  def parent
    @parent ||= ItemQueryService.find_modifiable_item(parent_druid)
  end
end