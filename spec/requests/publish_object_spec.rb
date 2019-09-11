# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Publish object' do
  let(:payload) { { sub: 'argo' } }
  let(:jwt) { JWT.encode(payload, Settings.dor.hmac_secret, 'HS256') }
  let(:object) { Dor::Item.new(pid: 'druid:1234') }

  before do
    allow(Dor).to receive(:find).and_return(object)
  end

  context 'with bad metadata' do
    let(:error_message) { "DublinCoreService#ng_xml produced incorrect xml (no children):\n<xml/>" }

    before do
      allow(PublishMetadataService).to receive(:publish).and_raise(DublinCoreService::CrosswalkError, error_message)
    end

    it 'returns a 409 error with location header' do
      post '/v1/objects/druid:1234/publish', headers: { 'X-Auth' => "Bearer #{jwt}" }
      expect(response.status).to eq(500)
      expect(response.body).to eq(error_message)
    end
  end

  context 'when the request is successful' do
    before do
      allow(PublishMetadataService).to receive(:publish)
    end

    it 'calls PublishMetadataService and returns 201' do
      post '/v1/objects/druid:1234/publish', headers: { 'X-Auth' => "Bearer #{jwt}" }

      expect(PublishMetadataService).to have_received(:publish)
      expect(response.status).to eq(201)
    end
  end
end