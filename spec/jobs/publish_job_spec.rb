# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PublishJob, type: :job do
  subject(:perform) { described_class.perform_now(druid: druid, background_job_result: result) }

  let(:druid) { 'druid:mk420bs7601' }
  let(:result) { create(:background_job_result) }
  let(:item) { instance_double(Dor::Item) }

  before do
    allow(Dor).to receive(:find).with(druid).and_return(item)
    allow(result).to receive(:processing!)
  end

  context 'with no errors' do
    before do
      allow(PublishMetadataService).to receive(:publish)
      perform
    end

    it 'marks the job as processing' do
      expect(result).to have_received(:processing!).once
    end

    it 'invokes the PublishMetadataService' do
      expect(PublishMetadataService).to have_received(:publish).with(item).once
    end

    it 'marks the job as complete' do
      expect(result).to be_complete
    end

    it 'has no output' do
      expect(result.output).to be_blank
    end
  end

  context 'with errors returned by PublishMetadataService' do
    let(:error_message) { "DublinCoreService#ng_xml produced incorrect xml (no children):\n<xml/>" }

    before do
      allow(PublishMetadataService).to receive(:publish).and_raise(Dor::DataError, error_message)
      perform
    end

    it 'marks the job as processing' do
      expect(result).to have_received(:processing!).once
    end

    it 'invokes the PublishMetadataService' do
      expect(PublishMetadataService).to have_received(:publish).with(item).once
    end

    it 'marks the job as complete' do
      expect(result).to be_complete
    end

    it 'has output with errors' do
      expect(result.output[:errors]).to eq [{ 'detail' => error_message, 'title' => 'Data error' }]
    end
  end
end