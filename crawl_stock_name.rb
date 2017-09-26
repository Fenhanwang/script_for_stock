require 'nokogiri'
require 'open-uri'
require 'elasticsearch'
require 'json'
require 'pp'
require 'csv'
require 'pry-byebug'

class CrawlStockName

  def initialize(zhang_fu)
    @url = "http://eoddata.com/stocklist/NASDAQ/%s.htm"
    @char_array = ("A".."Z").to_a
    @stock_abb_array = []
    @zhang_fu = zhang_fu # 0.3
  end

  def min_in_52_week
    crawl_stock_name
    loop_stock_array
  end

  def biao_zhun_cha
  	i = 1
    crawl_stock_name
    
    @stock_abb_array.each_slice(20) do |arr|
    	threads = []
	    arr.each { |e|
	      # cal_stock_trend(e, 30, "Close")
	      # cal_stock_trend(e, 30, "Volume", 100)
	      # cal_x_day_min_point(e, 30, "Close")
	      puts i if i%1000 == 0  
	      threads << Thread.new(e){|ee|cal_protential_zuokong(ee, 30, @zhang_fu)}
	      # threads << Thread.new(e){|ee| penny_stock(ee, 30, @zhang_fu)}
	      i+=1
	    }
	    # sleep 5
	    threads.each(&:join)
	end
	# @stock_abb_array.each { |e|
	# 	cal_protential_zuokong(e, 30, 0.3)
	# 	puts i
	# 	i+=1
	# 	sleep 1 if i % 15 == 0
	# 	sleep 0.5
	# }

  end

  def crawl_stock_name
    @char_array.each { |e|
      current_url = @url % [e]
      page = Nokogiri::HTML(open(current_url))
      page.xpath("//div[@id='ctl00_cph1_divSymbols']/table/tr")[1..-1].each { |tr|
      tds = tr.elements
      @stock_abb_array << tds.first.content
      }
    }

    puts "Stock Size is #{@stock_abb_array.size}"
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
        if change_percent < 50 && line[10] =~ /B|M/ && range_between > 20 && low_fiftytwo < 100
          puts line.join("---")
          puts "Change Percent: #{change_percent}%"
          puts ""
        end
      elsif line[5] != 'N/A' && line[7] != 'N/A'
        high_fiftytwo = line[6].to_f
        low_fiftytwo = line[5].to_f

        range_between = high_fiftytwo - low_fiftytwo
        current_value = ( line[7].gsub(/\+|\-|\%/, '').to_f / 100 + 1 ) * low_fiftytwo

        # if the percent is too high, which means market value is too high
        change_percent = ( ( ( current_value - low_fiftytwo ) / range_between ) * 100 ).to_i
        if change_percent < 50 && line[10] =~ /B|M/ && range_between > 20 && low_fiftytwo < 100
          puts line.join("---")
          puts "Change Percent: #{change_percent}%"
          puts ""
        end
      end
    end
  end

  def cal_stock_trend(stock_name, days, type, var_bar)
    yesterday_format  = ( Time.now - 1 * 3600 * 24 ).strftime("%Y-%m-%d")
    many_days_ago = ( Time.now - days * 3600 * 24 ).strftime("%Y-%m-%d")
    stock_name = stock_name.split("-").first
    # https://developer.yahoo.com/yql/console/?q=show%20tables&env=store://datatables.org/alltableswithkeys#h=select+*+from+yahoo.finance.historicaldata+where+symbol+%3D+%22YHOO%22+and+startDate+%3D+%222009-09-11%22+and+endDate+%3D+%222010-03-10%22
    res = open("https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.historicaldata%20where%20symbol%20%3D%20%22#{stock_name}%22%20and%20startDate%20%3D%20%22#{many_days_ago}%22%20and%20endDate%20%3D%20%22#{yesterday_format}%22&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=").read
    result_json = JSON.parse(res)
    return false if result_json['query']['results'].nil?
    begin
      input_array = result_json['query']['results']['quote'].map { |e| Float(e["#{type}"]) }
    rescue Exception => e
      puts "Error! #{result_json}"   
    end
    input_array = input_array.map { |e| Integer(e/10000) } if type == "Volume"
    var_res =  variance(input_array)
    if var_res > var_bar
      puts "====begin #{type}====", var_res, stock_name, "===end==="
      puts ""
    end
  end

  def cal_x_day_min_point(stock_name, days, type)
    yesterday_format  = ( Time.now - 1 * 3600 * 24 ).strftime("%Y-%m-%d")
    many_days_ago = ( Time.now - days * 3600 * 24 ).strftime("%Y-%m-%d")
    stock_name = stock_name.split("-").first
    # https://developer.yahoo.com/yql/console/?q=show%20tables&env=store://datatables.org/alltableswithkeys#h=select+*+from+yahoo.finance.historicaldata+where+symbol+%3D+%22YHOO%22+and+startDate+%3D+%222009-09-11%22+and+endDate+%3D+%222010-03-10%22
    res = open("https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.historicaldata%20where%20symbol%20%3D%20%22#{stock_name}%22%20and%20startDate%20%3D%20%22#{many_days_ago}%22%20and%20endDate%20%3D%20%22#{yesterday_format}%22&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=").read
    result_json = JSON.parse(res)
    return false if result_json['query']['results'].nil?
    begin
      input_array = result_json['query']['results']['quote'].map { |e| Float(e["#{type}"]) }
    rescue Exception => e
      puts "Error! #{result_json}"   
    end
    if input_array[0]/(input_array.min) < 0.4
    	puts "====begin #{type}====", stock_name, "===end==="
    	puts ""
	end  	
  end

  def penny_stock(stock_name, days, zhang_fu)
    # yesterday_format  = ( Time.now - 1 * 3600 * 24 ).strftime("%Y-%m-%d")
    # many_days_ago = ( Time.now - days * 3600 * 24 ).strftime("%Y-%m-%d")
	input_array = []
	error_array = []
    yesterday_format  = ( Time.now - 1 * 3600 * 24 ).strftime("%b+%d,+%Y")
    many_days_ago = ( Time.now - days * 3600 * 24 ).strftime("%b+%d,+%Y")
    stock_name = stock_name.split("-").first
    # Yahoo API is down. switch google 
    # https://stackoverflow.com/questions/11516633/how-to-work-with-google-finance
    # res = open("https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.historicaldata%20where%20symbol%20%3D%20%22#{stock_name}%22%20and%20startDate%20%3D%20%22#{many_days_ago}%22%20and%20endDate%20%3D%20%22#{yesterday_format}%22&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=").read
    # result_json = JSON.parse(res)
  	# return false if result_json['query']['results'].nil?


    url = "http://www.google.com/finance/historical?q=NASDAQ:#{stock_name}&startdate=#{many_days_ago}&enddate=#{yesterday_format}&output=CSV"
   	begin
	    CSV.new(open(url)).each do |line|
	    	close_value = line[4].to_f
	    	next if close_value == 0
	    	high_value  = line[2].to_f
	    	column = line[5].to_f
	    	input_array << { close_v: close_value, high_v: high_value, column: column }
	    end
   	rescue Exception => e
		error_array << "Error-->#{stock_name}, #{url}"
		return false  		
   	end
    return false if input_array.empty?
    begin
    max_price_within_one_month = input_array.map { |e| e[:high_v] }.max
    index_of_the_max = input_array.map { |e| e[:high_v] }.index(max_price_within_one_month)
    price_one_month_ago = input_array.map { |e| e[:close_v] }.last
    price_now = input_array.map { |e| e[:close_v] }.first
    min_colum = input_array.map { |e| e[:column] }.min
    # zhang fu da yu 30% and max price happened within 5 days
    if price_now < 1
    	puts "============="
    	puts stock_name, price_now, max_price_within_one_month, price_one_month_ago
    	puts "============="
    	puts ""
    	puts ""
  	end
    	
    rescue Exception => e
		binding.pry    	
    end
  	
  end

  def cal_protential_zuokong(stock_name, days, zhang_fu) # zhang_fu = 0.3 means 30%
    # yesterday_format  = ( Time.now - 1 * 3600 * 24 ).strftime("%Y-%m-%d")
    # many_days_ago = ( Time.now - days * 3600 * 24 ).strftime("%Y-%m-%d")
	input_array = []
	error_array = []
    yesterday_format  = ( Time.now - 1 * 3600 * 24 ).strftime("%b+%d,+%Y")
    many_days_ago = ( Time.now - days * 3600 * 24 ).strftime("%b+%d,+%Y")
    stock_name = stock_name.split("-").first
    # Yahoo API is down. switch google 
    # https://stackoverflow.com/questions/11516633/how-to-work-with-google-finance
    # res = open("https://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20yahoo.finance.historicaldata%20where%20symbol%20%3D%20%22#{stock_name}%22%20and%20startDate%20%3D%20%22#{many_days_ago}%22%20and%20endDate%20%3D%20%22#{yesterday_format}%22&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback=").read
    # result_json = JSON.parse(res)
  	# return false if result_json['query']['results'].nil?


    url = "http://www.google.com/finance/historical?q=NASDAQ:#{stock_name}&startdate=#{many_days_ago}&enddate=#{yesterday_format}&output=CSV"
   	begin
	    CSV.new(open(url)).each do |line|
	    	close_value = line[4].to_f
	    	next if close_value == 0
	    	high_value  = line[2].to_f
	    	column = line[5].to_f
	    	input_array << { close_v: close_value, high_v: high_value, column: column }
	    end
   	rescue Exception => e
		error_array << "Error-->#{stock_name}, #{url}"
		return false  		
   	end
    return false if input_array.empty?
    begin
    max_price_within_one_month = input_array.map { |e| e[:high_v] }.max
    index_of_the_max = input_array.map { |e| e[:high_v] }.index(max_price_within_one_month)
    price_one_month_ago = input_array.map { |e| e[:close_v] }.last
    price_now = input_array.map { |e| e[:close_v] }.first
    min_colum = input_array.map { |e| e[:column] }.min
    # zhang fu da yu 30% and max price happened within 5 days
    if ( (( max_price_within_one_month - price_one_month_ago ) / price_one_month_ago ) > zhang_fu ) and index_of_the_max < 7 and ( min_colum / 1000000 ) > 1
    	puts "============="
    	puts stock_name, price_now, max_price_within_one_month, price_one_month_ago
    	puts "============="
    	puts ""
    	puts ""
  	end
    	
    rescue Exception => e
		binding.pry    	
    end
    puts error_array
  end




  private

  # https://engineering.sharethrough.com/blog/2012/09/12/simple-linear-regression-using-ruby/
  def mean(values)
    total = values.reduce(0) { |sum, x| x + sum }
    Float(total) / Float(values.length)
  end


  def variance(array_values)
    x_mean = mean(array_values)
    denominator = array_values.reduce(0) do |sum, x|
      sum + ((x - x_mean) ** 2)
    end
    Math.sqrt(Float(denominator) / Float(array_values.length))
  end

  # def get_one_stock_data(market, stock)
  #   link = "http://finance.google.com/finance/info?client=ig&q=#{market}:#{stock}"
  #   re = open(link)
  #   body =  re.read
  #   binding.pry
  #   pp JSON.parse(body)
  # end
end

# CrawlStockName.new.min_in_52_week
puts "===================== >> 30% ================"
CrawlStockName.new(0.2).biao_zhun_cha
# CrawlStockName.new.cal_stock_trend("T", 40)


# CrawlStockName.new.get_stockinfo_from_yahoo("http://finance.yahoo.com/d/quotes.csv?s=AAPL+GOOG+NFLX&f=sabb2b3jkj6k5vj1")
# look at the reference here http://www.jarloo.com/yahoo_finance/