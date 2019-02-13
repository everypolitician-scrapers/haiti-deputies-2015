#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def members_data(url)
  noko = noko_for(url)

  # table id="table_separate"
  noko.xpath('//h4[contains(.,"partement")]//following-sibling::table[1]//tr[td]').map do |tr|
    tds = tr.css('td')

    area_data = tds[1].text.split("\n")
    #circ = tds[1].text.tidy.sub('unique circ', '1è circ').sub('circ. unique', '1è circ').sub('1ère circ.', '1è circ')
    circ = area_data[1].to_s.match(/(\d+)è\.?\s*circ\.?\s*d.\s*(.*)/) || []

    dep = tr.xpath('.//preceding::h4').last.text.tidy
    area = {
      departement: dep.sub(/DÉPARTEMENT /i, '').sub(/^(du|de l.)\s*/, '').sub(/:$/,''),
      district:    area_data.first,
      circ_id:     circ[1],
      circ:        circ[2],
    }
    area[:district] = 'Saint Marc' if area[:district] == 'St. Marc'
    # TODO handle missing parts
    area[:id] = 'ocd-division/country:ht/departement:%s/arrondissement:%s/circonscription:%s' %
      %i[departement district circ_id].map { |i| area[i].to_s.downcase.tr(' ', '_') }

    {
      name:    tds[0].text.tidy.sub('Siège vacant dû au décès de ', '').sub(/ \(.*?\)/, ''),
      region:  dep,
      area_id: area[:id],
      area:    area[:circ],
      party:   tds[2].text.tidy,
      term:    '2015',
      source:  url,
    }
  end
end

data = members_data('https://www.haiti-reference.com/pages/plan/politique/pouvoir-legislatif/chambre-des-deputes/')
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[name area_id], data)
