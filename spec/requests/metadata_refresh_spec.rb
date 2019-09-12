# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Refresh metadata' do
  let(:payload) { { sub: 'argo' } }
  let(:jwt) { JWT.encode(payload, Settings.dor.hmac_secret, 'HS256') }
  let(:object) { Dor::Item.new(pid: 'druid:1234') }

  before do
    allow(Dor).to receive(:find).and_return(object)
    allow(object).to receive(:save)
  end

  context 'when happy path' do
    before do
      allow(RefreshMetadataAction).to receive(:run).and_return('<xml />')
    end

    it 'updates the metadata and saves the changes' do
      post '/v1/objects/druid:mk420bs7601/refresh_metadata',
           headers: { 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_successful
      expect(RefreshMetadataAction).to have_received(:run).with(object)
      expect(object).to have_received(:save)
    end
  end

  describe 'errors in response from Symphony' do
    before do
      allow(object.identityMetadata).to receive(:otherId).and_return(['catkey:666'])
    end

    context 'when incomplete response' do
      before do
        stub_request(:get, format(Settings.catalog.symphony.json_url, catkey: '666')).to_return(body: '{}', headers: { 'Content-Length': 0 })
      end

      it 'returns a 500 error' do
        post '/v1/objects/druid:mk420bs7601/refresh_metadata',
             headers: { 'Authorization' => "Bearer #{jwt}" }
        expect(response.status).to eq(500)
        expect(response.body).to eq('Incomplete response received from Symphony for 666 - expected 0 bytes but got 2')
      end
    end

    context 'when catkey not found' do
      before do
        stub_request(:get, format(Settings.catalog.symphony.json_url, catkey: '666')).to_return(status: 404)
      end

      it 'returns a 500 error' do
        post '/v1/objects/druid:mk420bs7601/refresh_metadata',
             headers: { 'Authorization' => "Bearer #{jwt}" }
        expect(response.status).to eq(500)
        expect(response.body).to eq('Record not found in Symphony: 666')
      end
    end

    context 'when HTTP error' do
      let(:err_body) do
        {
          messageList: [
            {
              code: 'oops',
              message: 'Something somewhere went wrong.'
            }
          ]
        }
      end

      before do
        stub_request(:get, format(Settings.catalog.symphony.json_url, catkey: '666')).to_return(status: 403, body: err_body.to_json)
      end

      it 'returns a 500 error' do
        post '/v1/objects/druid:mk420bs7601/refresh_metadata',
             headers: { 'Authorization' => "Bearer #{jwt}" }
        expect(response.status).to eq(500)
        expect(response.body).to match(/^Got HTTP Status-Code 403 retrieving 666 from Symphony:.*Something somewhere went wrong./)
      end
    end
  end
end
