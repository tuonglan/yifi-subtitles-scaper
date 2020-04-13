require 'nokogiri'
require 'selenium-webdriver'
require 'optparse'

S_OPTIONS = Selenium::WebDriver::Chrome::Options.new()
S_OPTIONS.add_argument 'headless'
S_OPTIONS.add_argument 'no-proxy-server'
S_OPTIONS.add_argument "--proxy-server='direct://'"
S_OPTIONS.add_argument '--proxy-bypass-list=*'
driver = Selenium::WebDriver.for(:chrome, options: S_OPTIONS)
#driver = Selenium::WebDriver.for(:chrome)
wait = Selenium::WebDriver::Wait.new(timeout: 15)

method1 = proc do
    # Query yifi website
    puts 'Going to the main page...'
    driver.get 'https://www.yifysubtitles.com/'
    ele_search = driver.find_element(:name, 'q')

    # Search the Logan
    puts 'Searching for Logan...'
    ele_search.send_key 'Logan'
    ele_search.submit

    #puts 'Printing the result'
    #media_bodies = driver.find_elements(:class_name, 'media-body')
    #puts media_bodies[2].attribute('innerHTML')

    # Goto Logan page
    puts 'Going to Logan page...'
    #medias = wait.until { driver.find_elements(:class_name, 'media-movie-clickable') }
    medias = wait.until { driver.find_elements(:xpath, "//li[contains(@class, 'media-movie-clickable') and not(@disabled)]") }
    puts "Found #{medias.length} clickable..."
    medias[2].click
    

    # Get all subtitles
    puts "Get all subtitles... #{driver.title}"
    ele_table = wait.until { driver.find_element(:class_name, 'table-responsive') }
    ele_subs = ele_table.find_elements(:tag_name, 'tr')
    # ele_subs.each {|ele| puts ele.attribute('innerHTML')}

    # Go to to vietnamese download
    puts "Going to vietnamese subtitle page..."
    ele_vie_sub = ele_subs[-1]
    ele_download = ele_vie_sub.find_element(:class_name, 'download-cell')
    ele_download.click

    puts "Getting the link"
    ele_link = wait.until { driver.find_element(:class_name, 'download-subtitle') }
    puts ele_link.attribute('innerHTML')

    driver.close
end


# --------------------------------------------------
# -------------- Method 2 -------------------------
method2 = Proc.new do |name, year, len, lang|
    puts "Going to search page for #{name}..."
    driver.get "https://www.yifysubtitles.com/search?q=#{name}"

    puts "Going to the right #{name} page..."
    medias = wait.until { driver.find_elements(:class_name, 'media-movie-clickable') }
    puts "\tFound #{medias.length} clickables..., searching for the right one at year #{year}..."
    media = nil
    medias.each do |m|
        xml = Nokogiri::XML m.attribute('innerHTML')
        infos = xml.xpath "//span[@class='movinfo-section']"
        m_year = infos[0].xpath('child::text()').to_s.to_i
        m_length = infos[1].xpath('child::text()').to_s.to_i
        #puts "=====> m_year: #{m_year}, minutes: #{m_length}"
        if (year == 0 || m_year == year) && (len == 0 || m_length == len)
            media = m
            break
        end
    end

    if not media
        puts "Can't find movie #{name}, #{year}, #{len} minutes, exit now"
        return
    end
    xml_media = Nokogiri::XML media.attribute 'innerHTML'
    sub_link = xml_media.xpath("//div[@class='media-body']/a/@href")
    movie_link = "https://www.yifysubtitles.com#{sub_link}"
    puts "The movie found is: #{xml_media.xpath("//h3[@class='media-heading']")[0].content} - Genre: #{xml_media.xpath("//div[@itemprop='genre']")[0].content}"
    puts "\tMovie link: #{movie_link}"

    # Go the the movie page link
    puts "Going to the movie page..."
    driver.get movie_link
    ele_table = wait.until { driver.find_element(:class_name, 'table-responsive') }
    xml_table = Nokogiri::XML ele_table.attribute('innerHTML')

    # Searching for subtitle English
    puts "\tSearching for the first #{lang} subtitle..."
    xml_trs = xml_table.xpath("//tr")
    File.open('/tmp/yifi-subtitles-list.txt', 'w') do |sout|
        xml_trs.each do |tr|
            sout.puts "--------------------   =========================== ----------------------"
            sout.puts "----                                                          -----------"
            sout.puts tr
        end
    end
    eng_sub = nil
    xml_subs = xml_trs[1..-1]
    xml_subs.each do |sub|
        if sub.xpath(".//span[@class='sub-lang']")[0].content == lang
            eng_sub = sub
            break
        end
    end
    if not eng_sub
        puts "Can't find #{lang} subtitle for #{name}, #{year}, #{len}, exit now"
        return
    end
    eng_sub_link = eng_sub.xpath(".//a/@href")[0]
    eng_link = "https://www.yifysubtitles.com#{eng_sub_link}"
    puts "\tLink for #{lang} subtitle is: #{eng_link}"

    # Go to the subtitle download page
    puts "Going to the subtitle download page..."
    driver.get eng_link
    ele_down_link = wait.until { driver.find_element(:class_name, 'movie-main-info') }
    #puts "------------------------------------"
    #puts ele_down_link.attribute('innerHTML')
    xml_down_link = Nokogiri::HTML.parse(ele_down_link.attribute('innerHTML'))
    #puts "------------------------------------"
    #puts xml_down_link
    down_link = xml_down_link.xpath("//a/@href")[1]
    puts "Subtitle download link is: #{down_link}"

    driver.close
end

if __FILE__ == $0
    #method1.call
    # HELP
    # ruby test.rb <Movie title> <Movie year> [<Movie length in minute>]
    options = {
        lang: 'English',
        movie: 'Logan',
        year: nil,
        len: nil,
        }

    # Add argument
    OptionParser.new do |opts|
        opts.banner = 'Usage: ruby test.rb [OPTIONS]'
        opts.on('-m', '--movie M', "Specify the movie name") {|m| options[:movie] = m}
        opts.on('-l', '--lang L', "Specify the subtitle language") {|l| options[:lang] = l}
        opts.on('-y', '--year y', "Specify the movie year") {|y| options[:year] = y}
        opts.on('-L', '--len L', "Specify the movie length in minutes") {|l| options[:len] = l}
    end.parse!

    name = options[:movie].gsub(' ', '+')
    method2.call(name, options[:year].to_i, options[:len].to_i, options[:lang])
end
