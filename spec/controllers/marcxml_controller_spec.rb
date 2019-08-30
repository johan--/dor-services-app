# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MarcxmlController do
  before do
    login
  end

  let(:resource) { MarcxmlResource.new(catkey: '12345') }

  describe 'GET catkey' do
    it 'returns the provided catkey' do
      get :catkey, params: { catkey: '12345' }
      expect(response.body).to eq '12345'
    end

    it 'looks up an item by barcode' do
      stub_request(:get, format(Settings.catalog.barcode_search_url, barcode: '98765')).to_return(body: { barcode: '98765', id: '12345' }.to_json)
      get :catkey, params: { barcode: '98765' }
      expect(response.body).to eq '12345'
    end
  end

  describe 'GET marcxml' do
    it 'retrieves MARCXML' do
      stub_request(:get, format(Settings.catalog.symphony.json_url, catkey: resource.catkey)).to_return(body: '{}', headers: { 'Content-Length': 2 })
      get :marcxml, params: { catkey: '12345' }
      expect(response.body).to start_with '<record'
    end

    context 'when incomplete response from Symphony' do
      before do
        stub_request(:get, format(Settings.catalog.symphony.json_url, catkey: resource.catkey)).to_return(body: '{}', headers: { 'Content-Length': 0 })
      end

      it 'returns a 500 error' do
        get :marcxml, params: { catkey: '12345' }
        expect(response.status).to eq(500)
        expect(response.body).to eq('Incomplete response received from Symphony for 12345 - expected 0 bytes but got 2')
      end
    end
  end

  describe 'GET mods' do
    it 'transforms the MARCXML into MODS' do
      stub_request(:get, format(Settings.catalog.symphony.json_url, catkey: resource.catkey)).to_return(body: '{}', headers: { 'Content-Length': 2 })
      get :mods, params: { catkey: '12345' }
      expect(response.body).to match(/mods/)
    end

    context 'when incomplete response from Symphony' do
      before do
        stub_request(:get, format(Settings.catalog.symphony.json_url, catkey: resource.catkey)).to_return(body: '{}', headers: { 'Content-Length': 0 })
      end

      it 'returns a 500 error' do
        get :mods, params: { catkey: '12345' }
        expect(response.status).to eq(500)
        expect(response.body).to eq('Incomplete response received from Symphony for 12345 - expected 0 bytes but got 2')
      end
    end
  end
end
