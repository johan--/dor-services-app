module Dor
  class Goobi < ServiceItem
    def register
      handler = proc do |exception, attempt_number, _total_delay|
        error!("#{exception.class} on goobi notification web service call #{attempt_number} for #{@druid_obj.id}", 500) if attempt_number >= Dor::Config.goobi.max_tries
      end

      # rubocop:disable Metrics/LineLength
      with_retries(max_tries: Dor::Config.goobi.max_tries, handler: handler, base_sleep_seconds: Dor::Config.goobi.base_sleep_seconds, max_sleep_seconds: Dor::Config.goobi.max_sleep_seconds) do |_attempt|
        response = RestClient.post Dor::Config.goobi.url, xml_request, :content_type => 'text/xml'
        response.code
      end
      # rubocop:enable Metrics/LineLength
    end

    def xml_request
      <<-END
        <stanfordCreationRequest>
            <objectId>#{@druid_obj.id}</objectId>
            <objectType>#{object_type}</objectType>
            <sourceID>#{@druid_obj.source_id.encode(:xml => :text)}</sourceID>
            <title>#{@druid_obj.label.encode(:xml => :text)}</title>
            <contentType>#{content_type}</contentType>
            <project>#{project_name.encode(:xml => :text)}</project>
            <catkey>#{ckey}</catkey>
            <barcode>#{barcode}</barcode>
            <collectionId>#{collection_id}</collectionId>
            <collectionName>#{collection_name.encode(:xml => :text)}</collectionName>
            <sdrWorkflow>#{Dor::Config.goobi.dpg_workflow_name}</sdrWorkflow>
            <goobiWorkflow>#{goobi_workflow_name}</goobiWorkflow>
        </stanfordCreationRequest>
      END
    end
  end
end
