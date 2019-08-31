# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MarcxmlResource do
  subject(:marcxml_rsrc) { described_class.new(catkey: catkey) }

  let(:catkey) { 'catkey' }
  let(:symphony_url) { Settings.catalog.symphony.json_url % { catkey: catkey } }
  let(:body) do
    {
      resource: '/catalog/bib',
      key: catkey,
      fields: {
        bib: {
          standard: 'MARC21',
          type: 'BIB',
          leader: '00956cem 2200229Ma 4500',
          fields: [
            { tag: '008', subfields: [{ code: '_', data: '041202s2000    ja nnn  s      f    eng d' }] },
            { tag: '245', inds: '41', subfields: [{ code: 'a', data: 'the title' }] }
          ]
        }
      }
    }
  end

  describe '#marc_record' do
    let(:err_prefix) { 'MARC record catkey from Symphony should have exactly one populated' }

    context 'when missing leader' do
      before do
        body_len = 268
        my_body = Marshal.load(Marshal.dump(body))
        my_body[:fields][:bib].delete(:leader)
        stub_request(:get, symphony_url).to_return(body: my_body.to_json, headers: { 'Content-Length': body_len })
      end

      it 'raises InvalidMarcError' do
        expect { marcxml_rsrc.send(:marc_record) }.to raise_error(MarcxmlResource::InvalidMarcError, "#{err_prefix} leader")
      end
    end

    context 'when missing 008' do
      before do
        body_len = 212
        my_body = Marshal.load(Marshal.dump(body))
        my_body[:fields][:bib][:fields].delete_at(0)
        stub_request(:get, symphony_url).to_return(body: my_body.to_json, headers: { 'Content-Length': body_len })
      end

      it 'raises InvalidMarcError' do
        expect { marcxml_rsrc.send(:marc_record) }.to raise_error(MarcxmlResource::InvalidMarcError, "#{err_prefix} 008")
      end
    end

    context 'when missing 245' do
      before do
        body_len = 231
        my_body = Marshal.load(Marshal.dump(body))
        my_body[:fields][:bib][:fields].delete_at(1)
        stub_request(:get, symphony_url).to_return(body: my_body.to_json, headers: { 'Content-Length': body_len })
      end

      it 'raises InvalidMarcError' do
        expect { marcxml_rsrc.send(:marc_record) }.to raise_error(MarcxmlResource::InvalidMarcError, "#{err_prefix} 245")
      end
    end

    context 'when missing 245 subfield a' do
      before do
        body_len = 303
        my_body = Marshal.load(Marshal.dump(body))
        my_body[:fields][:bib][:fields][1][:subfields][0][:code] = 'b'
        stub_request(:get, symphony_url).to_return(body: my_body.to_json, headers: { 'Content-Length': body_len })
      end

      it 'raises InvalidMarcError' do
        expect { marcxml_rsrc.send(:marc_record) }.to raise_error(MarcxmlResource::InvalidMarcError, "#{err_prefix} 245 subfield a")
      end
    end

    context 'when empty 245 subfield a' do
      before do
        body_len = 294
        my_body = Marshal.load(Marshal.dump(body))
        my_body[:fields][:bib][:fields][1][:subfields][0][:data] = ''
        stub_request(:get, symphony_url).to_return(body: my_body.to_json, headers: { 'Content-Length': body_len })
      end

      it 'raises InvalidMarcError' do
        expect { marcxml_rsrc.send(:marc_record) }.to raise_error(MarcxmlResource::InvalidMarcError, "#{err_prefix} 245 subfield a")
      end
    end
  end
end
