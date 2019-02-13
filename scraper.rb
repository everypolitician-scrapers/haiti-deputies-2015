#!/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MembersPage < Scraped::HTML
  field :members do
    member_rows.map { |mp| fragment(mp => MemberRow).to_h }
  end

  private

  def member_rows
    noko.xpath('//h4[contains(.,"partement")]//following-sibling::table[1]//tr[td]')
  end
end

class MemberRow < Scraped::HTML
  field :name do
    tds[0].text.tidy.sub('Siège vacant dû au décès de ', '').sub(/ \(.*?\)/, '')
  end

  field :region do
    noko.xpath('.//preceding::h4').last.text.tidy.sub(/DÉPARTEMENT /i, '').sub(/^(du|de l.)\s*/, '').sub(/:$/, '')
  end

  field :area_id do
    ocd = 'ocd-division/country:ht/departement:%s' % region.downcase.tr(' ', '_')
    ocd += '/arrondissement:%s' % district.downcase.tr(' ', '_') if district
    ocd += '/circonscription:%s' % circonscription_id.downcase.tr(' ', '_') if circonscription_id
    ocd
  end

  field :area do
    circonscription
  end

  field :party do
    tds[2].text.tidy
  end

  field :term do
    '2015'
  end

  field :source do
    url
  end

  private

  def tds
    noko.css('td')
  end

  def area_data
    tds[1].text.split("\n")
  end

  def circ_parts
    area_data[1].to_s.match(/(\d+)è\.?\s*circ\.?\s*d\w+\s*(.*)/) || []
  end

  def circonscription
    circ_parts[2]
  end

  def circonscription_id
    circ_parts[1]
  end

  def district
    area_data.first
  end
end

url = 'https://www.haiti-reference.com/pages/plan/politique/pouvoir-legislatif/chambre-des-deputes/'
Scraped::Scraper.new(url => MembersPage).store(:members, index: %i[name area_id])
