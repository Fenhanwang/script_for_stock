require 'nokogiri'
require 'open-uri'
require 'elasticsearch'
require 'json'
require 'pp'
require 'csv'

class CrawlStockName

  def initialize
    @url = "http://eoddata.com/stocklist/NYSE/%s.htm"
    @char_array = ("A".."Z").to_a
    @stock_abb_array = []
  end

  def crawl
    crawl_stock_name
    loop_stock_array
  end

  def crawl_stock_name
    @char_array.each { |e|
      current_url = @url % [e]
      page = Nokogiri::HTML(open(current_url))
      page.xpath("//div[@id='ctl00_cph1_divSymbols']/table/tr")[1..-1].each { |tr|
      tds = tr.elements
      # puts tds.first.content
      @stock_abb_array << tds.first.content
      }
    }
    puts @stock_abb_array.size
  end

  def loop_stock_array
    @stock_abb_array.each_slice(100) {|su_arr|
      sub_url  = su_arr.join("+")

      # s: Symbol, a: Ask, b: Bid, b2: Ask (Realtime), b3: Bid (Realtime), k: 52 Week High, j: 52 week Low, 
      # j6: Percent Change From 52 week Low, k5: Percent Change From 52 week High, v: Volume, j1: Market Capitalization
      full_url = "http://finance.yahoo.com/d/quotes.csv?s=#{sub_url}&f=sabb2b3jkj6k5vj1"
      get_stockinfo_from_yahoo(full_url)
    }
  end

  def get_stockinfo_from_yahoo(url)
    CSV.new(open(url)).each do |line|
      if line[1] != "N/A"
        current_value = line[1].to_f
        low_fiftytwo = line[5].to_f
        high_fiftytwo = line[6].to_f
        range_between = high_fiftytwo - low_fiftytwo

        # if the percent is too high, which means market value is too high
        change_percent = ( ( ( current_value - low_fiftytwo ) / range_between ) * 100 ).to_i
        puts line
        puts ""
        if change_percent < 50 && line[10] =~ /B/ && range_between > 20 && low_fiftytwo < 100
          puts line.join("---")
          puts change_percent
          puts ""
        end
      elsif line[5] != 'N/A' && line[7] != 'N/A'
        high_fiftytwo = line[6].to_f
        low_fiftytwo = line[5].to_f

        range_between = high_fiftytwo - low_fiftytwo
        current_value = ( line[7].gsub(/\+|\-|\%/, '').to_f / 100 + 1 ) * low_fiftytwo

        # if the percent is too high, which means market value is too high
        change_percent = ( ( ( current_value - low_fiftytwo ) / range_between ) * 100 ).to_i
        if change_percent < 50 && line[10] =~ /B/ && range_between > 20 && low_fiftytwo < 100
          puts line.join("---")
          puts change_percent
          puts ""
        end
      end
    end
  end

  # def get_one_stock_data(market, stock)
  #   link = "http://finance.google.com/finance/info?client=ig&q=#{market}:#{stock}"
  #   re = open(link)
  #   body =  re.read
  #   binding.pry
  #   pp JSON.parse(body)
  # end
end

CrawlStockName.new.crawl


# CrawlStockName.new.get_stockinfo_from_yahoo("http://finance.yahoo.com/d/quotes.csv?s=AAPL+GOOG+NFLX&f=sabb2b3jkj6k5vj1")
# look at the reference here http://www.jarloo.com/yahoo_finance/