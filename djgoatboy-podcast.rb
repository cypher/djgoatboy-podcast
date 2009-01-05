#!/usr/local/bin/ruby
require 'rubygems'
require 'simple-rss'
require 'open-uri'
require 'builder'

def untinyurl(str)
  if str =~ %r{(http://tinyurl\.com/[a-zA-Z0-9]+)}
    Net::HTTP.get_response( URI.parse($1) )["location"]
  else
    nil
  end
end

def mp3_length(url)
  uri = URI.parse(url)
  resp = nil
  Net::HTTP.start(uri.host, uri.port) {|http|
    resp = http.head(uri.path)
  }
  resp["content-length"]
end

DJGOATBOY_FEED = 'http://twitter.com/statuses/user_timeline/17939483.atom'
PODCAST_FILE = File.expand_path("~/www/nuclearsquid.com/djgoatboy.rss")

begin
  feed = SimpleRSS.parse( open(DJGOATBOY_FEED) )

  builder = Builder::XmlMarkup.new
  builder.instruct!
  # There's gotta be a better way than this
  podcast = builder.rss("version" => "2.0") { |rss|
    rss.channel { |channel|
      channel.title feed.title.gsub(/Twitter \/ /, '')
      channel.link feed.link
      channel.language 'en-US'

      feed.entries.each do |entry|
        if entry.content =~ %r{(http://tinyurl\.com/[a-zA-Z0-9]+)}
          url = untinyurl(entry.content)

          # Make sure we're getting a mp3
          if url =~ /\.mp3$/
            length = mp3_length(url)

            channel.item {|item|
              item.title entry.title
              item.link entry.link
              item.description entry.content

              # Right now, we'll trust giles to only release mp3s
              item.enclosure("url" => url, "length" => length, "type" => "audio/mpeg")
              item.pubDate entry.published
            }
          end
        end
      end
    }
  }

  File.open(PODCAST_FILE, 'w+') do |f|
    f.write( podcast )
  end
rescue OpenURI::HTTPError
  # Don't do anything, just write to stderr
  $stderr.puts "Failed to open atom feed"
end

