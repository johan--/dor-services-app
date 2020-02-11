# frozen_string_literal: true

module Cocina
  # Maps Dor::Items to Cocina objects
  # rubocop:disable Metrics/ClassLength
  class Mapper
    # Raised when called on something other than an item or collection
    class UnsupportedObjectType < StandardError; end

    def self.build(item)
      new(item).build
    end

    def initialize(item)
      @item = item
    end

    def build
      klass = cocina_klass
      props = if klass == Cocina::Models::DRO
                dro_props
              elsif klass == Cocina::Models::Collection
                collection_props
              elsif klass == Cocina::Models::AdminPolicy
                apo_props
              else
                raise "unable to build '#{klass}'"
              end
      klass.new(props)
    end

    # This handles Dor::Item and Dor::Etd models
    def dro_props
      {
        externalIdentifier: item.pid,
        type: dro_type,
        label: item.label,
        version: item.current_version,
        administrative: build_administrative,
        description: build_descriptive
      }.tap do |props|
        if item.embargoMetadata.release_date
          props[:access] = {
            embargoReleaseDate: item.embargoMetadata.release_date.iso8601
          }
        end
        unless item.is_a?(Dor::Etd) || item.contentMetadata.new?
          props[:structural] = {
            contains: build_filesets(item.contentMetadata, version: item.current_version, id: item.pid)
          }
        end
      end
    end

    def collection_props
      {
        externalIdentifier: item.pid,
        type: Cocina::Models::Vocab.collection,
        label: item.label,
        version: item.current_version,
        administrative: build_administrative,
        description: build_descriptive
      }
    end

    def apo_props
      {
        externalIdentifier: item.pid,
        type: Cocina::Models::Vocab.admin_policy,
        label: item.label,
        version: item.current_version,
        administrative: build_apo_administrative,
        description: build_descriptive
      }
    end

    private

    attr_reader :item

    def dro_type
      case item.content_type_tag
      when 'Image'
        Cocina::Models::Vocab.image
      when '3D'
        Cocina::Models::Vocab.three_dimensional
      when 'Map'
        Cocina::Models::Vocab.map
      when 'Media'
        Cocina::Models::Vocab.media
      when /^Manuscript/
        Cocina::Models::Vocab.manuscript
      when /^Book/
        Cocina::Models::Vocab.book
      else
        Cocina::Models::Vocab.object
      end
    end

    def build_descriptive
      case item
      when Dor::Etd
        { title: [{ primary: true, titleFull: item.properties.title.first }] }
      else
        { title: [{ primary: true, titleFull: item.full_title }] }
      end
    end

    def build_filesets(content_metadata_ds, version:, id:)
      content_metadata_ds.ng_xml.xpath('//resource').map do |resource_node|
        files = build_files(resource_node.xpath('file'), version: version, parent_id: id)
        structural = {}
        structural[:contains] = files if files.present?
        Cocina::Models::FileSet.new(
          externalIdentifier: resource_node['id'],
          type: Cocina::Models::Vocab.fileset,
          label: resource_node.xpath('label').text,
          version: version,
          structural: structural
        )
      end
    end

    def build_files(file_nodes, version:, parent_id:)
      file_nodes.map do |node|
        Cocina::Models::File.new(
          externalIdentifier: "#{parent_id}/#{node['id']}",
          type: Cocina::Models::Vocab.file,
          label: node['id'],
          version: version
        )
      end
    end

    def build_apo_administrative
      {}.tap do |admin|
        registration_workflow = item.administrativeMetadata.ng_xml.xpath('//administrativeMetadata/dissemination/workflow/@id').text
        admin[:default_object_rights] = item.defaultObjectRights.content
        admin[:registration_workflow] = registration_workflow.presence
        admin[:hasAdminPolicy] = item.admin_policy_object_id
      end
    end

    def build_administrative
      {}.tap do |admin|
        admin[:releaseTags] = build_release_tags
        admin[:hasAdminPolicy] = item.admin_policy_object_id
      end
    end

    def build_release_tags
      item.identityMetadata.ng_xml.xpath('//release').map do |node|
        {
          to: node.attributes['to'].value,
          what: node.attributes['what'].value,
          date: node.attributes['when'].value,
          who: node.attributes['who'].value,
          release: node.text
        }
      end
    end

    # @todo This should have more speicific type such as found in identityMetadata.objectType
    def cocina_klass
      case item
      when Dor::Item, Dor::Etd
        Cocina::Models::DRO
      when Dor::Collection
        Cocina::Models::Collection
      when Dor::AdminPolicyObject
        Cocina::Models::AdminPolicy
      else
        raise UnsupportedObjectType, "Unknown type for #{item.class}"
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
