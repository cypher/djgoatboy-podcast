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
begin
  feed = SimpleRSS.parse( open(DJGOATBOY_FEED) )

  builder = Builder::XmlMarkup.new

  builder.instruct!
  podcast = builder.rss("version" => "2.0") { |rss|
    rss.channel { |channel|
      channel.title feed.title.gsub(/Twitter \/ /, '')
      channel.link feed.link
      channel.language 'en-US'

      feed.entries.each do |entry|
        if entry.content =~ %r{(http://tinyurl\.com/[a-zA-Z0-9]+)}
          channel.item {|item|
            item.title entry.title
            item.link entry.link
            item.description entry.content


            url = untinyurl(entry.content)
            length = mp3_length(url)

            # Right now, we'll trust giles to only release mp3s
            item.enclosure("url" => url, "length" => length, "type" => "audio/mpeg")
            item.pubDate entry.published
          }
        end
      end
    }
  }

  File.open("podcast.rss", 'w+') do |f|
    f.write( podcast )
  end
rescue OpenURI::HTTPError
  # Don't do anything, just write to stderr
  $stderr.puts "Failed to open atom feed"
end

