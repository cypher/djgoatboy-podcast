#!/usr/local/bin/ruby
require 'rubygems'
gem 'twitter'
require 'twitter'
require 'builder'
require 'fileutils'

TINYURLS_YAML = File.join(File.dirname(__FILE__), 'tinyurls.yml')
TINYURLS = YAML.load_file(TINYURLS_YAML) rescue {}

TINYURL_REGEX = %r{(http://(?:tinyurl\.com|bit\.ly|jm\.p)/[a-zA-Z0-9]+)}
HTTP_REGEX = URI.regexp(%w(http))

def untinyurl(url)
  if url =~ TINYURL_REGEX
    return TINYURLS[$1] if TINYURLS[$1]

    TINYURLS[$1] = Net::HTTP.get_response( URI.parse($1) )["location"]
  else
    url
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

PODCAST_FILE = File.expand_path("djgoatboy.rss")

begin
  config = YAML.load_file(File.expand_path("~/.twitter_config.yml"))
  # Use SuperTweet.Net to get to twitter via Basic Auth
  httpauth = Twitter::HTTPAuth.new config['user'], config['password'], :api_endpoint => 'api.supertweet.net' #, :ssl => true

  client = Twitter::Base.new(httpauth)
  tweets = client.user_timeline(:id => "djgoatboy")

  File.open(PODCAST_FILE + '.new', 'w+') do |file|
    builder = Builder::XmlMarkup.new(:target => file, :indent => 4)
    builder.instruct!
    # There's gotta be a better way than this
    podcast = builder.rss("version" => "2.0") { |rss|
      rss.channel { |channel|
        channel.title "@djgoatboy's mp3 feed"
        channel.link "http://twitter.com/djgoatboy"
        channel.language 'en-US'

        tweets.each do |tweet|
          if tweet.text =~ HTTP_REGEX
            url = untinyurl(tweet.text.slice(HTTP_REGEX))

            # Make sure we're getting a mp3
            if url =~ /\.mp3$/
              length = mp3_length(url)

              channel.item {|item|
                item.title "@djgoatboy / #{Time.parse(tweet.created_at).strftime("%d-%m-%Y")}"
                item.link "http://twitter.com/djgoatboy/status/#{tweet.id}"

                description = tweet.text.gsub(%r{\s*#{HTTP_REGEX}\s*}, '')

                if description.empty?
                  item.description "(no description)"
                else
                  item.description description
                end

                # Right now, we'll trust giles to only release mp3s
                item.enclosure("url" => url, "length" => length, "type" => "audio/mpeg")
                item.pubDate tweet.created_at
              }
            end
          end
        end
      }
    }
  end

  FileUtils.mv( PODCAST_FILE + '.new', PODCAST_FILE )

  File.open(TINYURLS_YAML, 'w+') do |f|
    f << YAML.dump(TINYURLS)
  end
end
