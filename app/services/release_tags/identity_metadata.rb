# frozen_string_literal: true

class ReleaseTags
  class IdentityMetadata
    # Determine projects in which an item is released
    # @param [Dor::Item] item to get the release tags for
    # @return [Hash{String => Boolean}] all namespaces, keys are Project name Strings, values are Boolean
    def self.for(item)
      new(item)
    end

    def initialize(item)
      @item = item
    end

    # Called in Dor::UpdateMarcRecordService (in dor-services-app too)
    # Determine projects in which an item is released
    # @param [Hash{String => Boolean}] the released hash to add tags to
    # @return [Hash{String => Boolean}] all namespaces, keys are Project name Strings, values are Boolean
    def released_for(released_hash)
      # Get the most recent self tag for all targets and retain their result since most recent self always trumps any other non self tags
      latest_self_tags = newest_release_tag self_release_tags(release_tags)
      latest_self_tags.each do |key, payload|
        released_hash[key] = { 'release' => payload['release'] }
      end

      # With Self Tags resolved we now need to deal with tags on all sets this object is part of.
      # Get all release tags on the item and strip out the what = self ones, we've already processed all the self tags on this item.
      # This will be where we store all tags that apply, regardless of their timestamp:
      potential_applicable_release_tags = tags_for_what_value(release_tags_for_item_and_all_governing_sets, 'collection')
      administrative_tags = AdministrativeTags.for(item: item) # Get admin tags once here and pass them down

      # We now have the keys for all potential releases, we need to check the tags: the most recent timestamp with an explicit true or false wins.
      # In a nil case, the lack of an explicit false tag we do nothing.
      # Don't bother checking if already added to the release hash, they were added due to a self tag so that has won
      (potential_applicable_release_tags.keys - released_hash.keys).each do |key|
        latest_tag = latest_applicable_release_tag_in_array(potential_applicable_release_tags[key], administrative_tags)
        next if latest_tag.nil? # Otherwise, we have a valid tag, record it

        released_hash[key] = { 'release' => latest_tag['release'] }
      end
      released_hash
    end

    # Take an item and get all of its release tags and all tags on collections it is a member of it
    # @return [Hash] a hash of all tags
    def release_tags_for_item_and_all_governing_sets
      return_tags = release_tags || {}
      item.collections.each do |collection|
        next if collection.id == item.id # recursive, so parents of parents are found, but we need to avoid an infinite loop if the collection references itself (i.e. bad data)

        release_service = self.class.for(collection)
        return_tags = combine_two_release_tag_hashes(return_tags, release_service.release_tags_for_item_and_all_governing_sets)
      end
      return_tags
    end

    # Take a hash of tags as obtained via Dor::Item.release_tags and returns the newest tag for each namespace
    # @param tags [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    # @return [Hash] a hash of latest tags for each to value
    def newest_release_tag(tags)
      Hash[tags.map { |key, val| [key, newest_release_tag_in_an_array(val)] }]
    end

    private

    delegate :release_tags, to: :item

    # Take a hash of tags as obtained via Dor::Item.release_tags and returns all self tags
    # @param tags [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    # @return [Hash] a hash of self tags for each to value
    def self_release_tags(tags)
      tags_for_what_value(tags, 'self')
    end

    # Take a hash of tags and return all tags with the matching what target
    # @param tags [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    # @param what_target [String] the target for the 'what' key, self or collection
    # @return [Hash] a hash of self tags for each to value
    def tags_for_what_value(tags, what_target)
      return_hash = {}
      tags.keys.each do |key|
        self_tags = tags[key].select { |tag| tag['what'].casecmp(what_target) == 0 }
        return_hash[key] = self_tags unless self_tags.empty?
      end
      return_hash
    end

    # Take two hashes of tags and combine them, will not overwrite but will enforce uniqueness of the tags
    # @param hash_one [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    # @param hash_two [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    # @return [Hash] the combined hash with uniquiness enforced
    def combine_two_release_tag_hashes(hash_one, hash_two)
      hash_two.keys.each do |key|
        hash_one[key] = hash_two[key] if hash_one[key].nil?
        hash_one[key] = (hash_one[key] + hash_two[key]).uniq unless hash_one[key].nil?
      end
      hash_one
    end

    # Takes an array of release tags and returns the most recent one
    # @param array_of_tags [Array] an array of hashes, each hash a release tag
    # @return [Hash] the most recent tag
    def newest_release_tag_in_an_array(array_of_tags)
      latest_tag_in_array = array_of_tags[0] || {}
      array_of_tags.each do |tag|
        latest_tag_in_array = tag if tag['when'] > latest_tag_in_array['when']
      end
      latest_tag_in_array
    end

    # Takes a tag and returns true or false if it applies to the specific item
    # @param release_tag [Hash] the tag in a hashed form
    # @param admin_tags [Array] the administrative tags on an item, if not supplied it will attempt to retrieve them
    # @return [Boolean] true or false if it applies (not true or false if it is released, that is the release_tag data)
    def does_release_tag_apply(release_tag, admin_tags = false)
      # Is the tag global or restricted
      return true if release_tag['tag'].nil? # no specific tag specificied means this tag is global to all members of the collection

      # We use false instead of [], since an item can have no admin_tags at
      # which point we'd be passing this var as [] and would not attempt to
      # retrieve it
      admin_tags ||= AdministrativeTags.for(item: item)
      admin_tags.include?(release_tag['tag'])
    end

    # Takes an array of release tags and returns the most recent one that applies to this item
    # @param release_tags [Array] an array of release tags in hashed form
    # @param admin_tags [Array] the administrative tags on an on item
    # @return [Hash] the tag, or nil if none applicable
    def latest_applicable_release_tag_in_array(release_tags, admin_tags)
      newest_tag = newest_release_tag_in_an_array(release_tags)
      return newest_tag if does_release_tag_apply(newest_tag, admin_tags)

      # The latest tag wasn't applicable, slice it off and try again
      # This could be optimized by reordering on the timestamp and just running down it instead of constantly resorting, at least if we end up getting numerous release tags on an item
      release_tags.slice!(release_tags.index(newest_tag))

      return latest_applicable_release_tag_in_array(release_tags, admin_tags) unless release_tags.empty? # Try again after dropping the inapplicable

      nil # We're out of tags, no applicable ones
    end

    attr_reader :item
  end
end
