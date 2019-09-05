# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Get the object' do
  let(:payload) { { sub: 'argo' } }
  let(:jwt) { JWT.encode(payload, Settings.dor.hmac_secret, 'HS256') }
  let(:basic_auth) { ActionController::HttpAuthentication::Basic.encode_credentials(user, password) }
  let(:object) { Dor::Item.new(pid: 'druid:1234') }

  before do
    allow(Dor).to receive(:find).and_return(object)
  end

  context 'when the object exists' do
    before do
      object.descMetadata.title_info.main_title = 'Hello'
      object.label = 'foo'
    end

    it 'returns the object' do
      get '/v1/objects/druid:mk420bs7601',
          headers: { 'X-Auth' => "Bearer #{jwt}" }
      expect(response).to be_successful
      expect(response.body).to eq '{"externalIdentifier":"druid:1234","type":"object","label":"foo"}'
    end
  end
end