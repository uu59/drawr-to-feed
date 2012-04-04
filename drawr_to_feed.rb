#!/usr/bin/env ruby
# -- coding: utf-8

require "time"
require "optparse"
require "rubygems"
require "bundler/setup"
Bundler.require

opts = {}
OptionParser.new do |opt|
  opt.on('-i VAL', '--id=VAL', 'id of drawr page'){|v| opts[:id] = v}
  opt.on('--stdout', 'print to STDOUT'){|v| opts[:stdout] = true}
  opt.parse! ARGV
end

id = opts[:id]
raise "didn't set target id (missing -i option)" unless id
savefile = "#{File.dirname(__FILE__)}/#{id}.atom"
raise "cannot create #{savefile}" if !FileUtils.touch(savefile) && !opts[:stdout]
url = "http://drawr.net/show.php?id=#{id}"
res = Typhoeus::Request.get(url)
if res.code > 399
  puts "server return #{res.code} for #{url}"
  exit
end

doc = Nokogiri::HTML.parse(res.body)
@entries = doc.xpath('//div[@id="pixiv"]//div[contains(@class, "permalinkEntry")]').map do |entry|
  prev = entry.previous
  while prev = prev.previous
    break if prev.nil?
    break if prev.node_name.upcase == "A"
  end
  rid = prev.attributes["name"].text if prev
  {
    :link => url + "#" + (rid || ""),
    :title => rid || url,
    :updated_at => Time.parse(entry.at('div[@class="mgnTop3"]//a')),
    :image => URI.join(url, entry.at('div[@class="floleft"]//a/img').attributes["src"].to_s).to_s,
    :raw => entry,
  }
end.reverse
@id = id
@url = url
erb = Erubis::FastEruby.new(DATA.read)
feed = erb.result(binding())
if opts[:stdout]
  puts feed
  exit
end

File.open(savefile, "w"){|f| f.print feed}

__END__
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>drawr #<%== @id %></title>
  <link href="<%== @url %>" rel="alternate" />
  <updated><%== @entries.sort_by{|p| p[:updated_at]}.first[:updated_at].strftime('%Y-%m-%dT%H:%M:%S+09:00') %></updated>
  <id><%== @url %></id>

  <% @entries.each do |post| %>
    <entry>
      <link href="<%== post[:link] %>"/>
      <title><%== post[:title] %></title>
      <id>tag:drawr.pixiv.net,<%== post[:updated_at].strftime('%Y-%m-%d') %>:/<%== post[:id] %>/</id>
      <updated><%== post[:updated_at].strftime('%Y-%m-%dT%H:%M:%S+09:00') %></updated>
      <content type="html">
        &lt;p&gt;<%== post[:title] %>&lt;/p&gt;
        &lt;img src="<%== post[:image] %>" /&gt;
        &lt;p&gt;Posted by:&lt;/p&gt;
        <%== post[:raw].at('div[@class="infoBox"]').to_xml %>
      </content>
    </entry>
  <% end %>

</feed>
