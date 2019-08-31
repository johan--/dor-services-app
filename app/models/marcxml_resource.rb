# frozen_string_literal: true

# MARC resource model for retrieving and transforming MARC records
class MarcxmlResource
  class InvalidMarcError < RuntimeError; end

  def self.find_by(catkey: nil, barcode: nil)
    if catkey
      new(catkey: catkey)
    elsif barcode
      barcode_search_url = format(Settings.catalog.barcode_search_url, barcode: barcode)
      response = Faraday.get(barcode_search_url)
      catkey = JSON.parse(response.body)['id']

      new(catkey: catkey)
    else
      raise ArgumentError, 'Must supply either a catkey or barcode'
    end
  end

  attr_reader :catkey

  def initialize(catkey:)
    @catkey = catkey
  end

  def mods
    marc_to_mods_xslt.transform(Nokogiri::XML(marcxml)).to_xml
  end

  def marcxml
    marc_record.to_xml.to_s
  end

  private

  def marc_to_mods_xslt
    @marc_to_mods_xslt ||= Nokogiri::XSLT(File.open(File.join(Rails.root, 'app', 'xslt', 'MARC21slim2MODS3-6_SDR_v1.xsl')))
  end

  def marc_record
    mr = SymphonyReader.new(catkey: catkey).to_marc
    mr.fields.freeze
    validate_marc_record(mr)
  end

  def validate_marc_record(marc_rec)
    err_prefix = "MARC record #{catkey} from Symphony should have exactly one populated"
    raise InvalidMarcError, "#{err_prefix} leader" if marc_rec.leader.blank?

    cf001s = marc_rec.fields('001')
    raise InvalidMarcError, "#{err_prefix} 001" if cf001s.length != 1 || cf001s.first.value.blank?

    cf008s = marc_rec.fields('008')
    raise InvalidMarcError, "#{err_prefix} 008" if cf008s.length != 1 || cf008s.first.value.blank?

    df245s = marc_rec.fields('245')
    raise InvalidMarcError, "#{err_prefix} 245" if df245s.length != 1

    sub_as = df245s[0].find_all { |subfield| subfield.code == 'a' }
    raise InvalidMarcError, "#{err_prefix} 245 subfield a" if sub_as.length != 1 || sub_as.first.value.blank?

    marc_rec
  end
end
