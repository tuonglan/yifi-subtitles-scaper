require 'selenium-webdriver'
require 'nokogiri'
require 'cgi'


module Yify
    S_OPTIONS = Selenium::WebDriver::Chrome::Options.new(args: ['headless'])
    S_OPTIONS.add_argument '--no-proxy-server'
    YIFY = "https://www.yifysubtitles.com"
    BLURAY = /blu-ray|bluray|bdrip|brip|brrip|bdr/
    WEBRIP = /web-dl|webrip|web|web-rip|webdl/

    class SubScraper
        def initialize title, langs, year=nil, length=nil, source=nil, logger: 
            @logger = logger

            @original_title = title
            @title = CGI.escape title
            @langs = langs
            @year = year
            @length = length
            @source = source
        end

        def get_sub_links
            @driver = Selenium::WebDriver.for(:chrome, options: S_OPTIONS)
            @wait = Selenium::WebDriver::Wait.new(timeout: 15)
            
            begin
                @logger.info "Searching movie #{@title}, year: #{@year}, length: #{@length}, source #{@source}"
                movie_link = self._get_movie_link
                if not movie_link
                    @logger.info "Can't find the subtitle for #{@title}"
                    return
                end

                @logger.info "Searching subtitles #{@langs} for movie #{@title}, source #{@source}"
                sub_page_links = self._get_sub_page_links movie_link
                sub_page_links.each { |lang, page| @logger.warn "#{lang} subtitle is not available for #{@title}" if not page }
                
                @logger.info "Getting download links for #{@langs} for movie #{@title}"
                sub_page_links = self._get_sub_down_links sub_page_links
            rescue => e
                @logger.error "Can't find subtitles #{@langs} for #{@title}: #{e.message}"
                @logger.error e.backtrace.join("\n")
                return nil
            ensure
                @driver.quit
            end

            return sub_page_links
        end

        def _get_movie_link
            # Go the the page
            link = "#{YIFY}/search?q=#{@title}"
            @logger.debug "Going to search page #{link}..."
            @driver.get link
            ele_medias = @wait.until { @driver.find_elements(:class_name, "media-movie-clickable") }
            @logger.debug "Found #{ele_medias.length} movies for #{@title}"

            # Search forthe right page
            xml_media = -> do
                ele_medias.each do |med|
                    xml_med = Nokogiri::XML med.attribute('innerHTML')
                    m_infos = xml_med.xpath "//span[@class='movinfo-section']"
                    m_year = m_infos[0].xpath('child::text()').to_s.to_i
                    m_length = m_infos[1].xpath('child::text()').to_s.to_i
                    puts "m_year: #{m_year}, m_length: #{m_length}"
                    return xml_med if (@year == 0 || m_year == @year) && (@length == 0 || m_length == @length)
                end
                return nil
            end.call()
            return nil if not xml_media

            media_link = xml_media.xpath("//div[@class='media-body']/a/@href")
            @logger.debug "The movie found is: #{xml_media.xpath("//h3[@class='media-heading']")[0].content} - Genre: #{xml_media.xpath("//div[@itemprop='genre']")[0].content}"
            return "#{YIFY}#{media_link}"
        end

        def _get_sub_page_links media_link
            @logger.debug "Going to the movie page #{media_link}..."
            @driver.get media_link
            ele_table = @wait.until { @driver.find_element(:class_name, 'table-responsive') }
            xml_table = Nokogiri::XML ele_table.attribute('innerHTML')

            # Get tables of subtitles
            links = {}
            @langs.each {|l| links[l] = []}
            sub_links = Hash[@langs.product]
            xml_trs = xml_table.xpath("//tr")[1..-1]
            @logger.debug "Found #{xml_trs.length} subtitles for #{@title}"
            xml_trs.each do |tr|
                lang = tr.xpath(".//span[@class='sub-lang']")[0].content
                
                # Skip if not choosen
                if ! sub_links.key? lang
                    @logger.debug "Skip #{lang}, not in the requested list"
                    next
                end
                if sub_links[lang]
                    @logger.debug "Skip #{lang}, already choosen"
                    next
                end

                # Skipp if source is different
                if @source
                    source = @source.downcase
                    txt = tr.xpath(".//a")[0].content.downcase
                    if not txt.include? source
                        @logger.debug "Skip #{txt} because not for source #{@source}"

                        # Save to links for later usage
                        links[lang] << ["#{YIFY}#{tr.xpath(".//a/@href")[0]}", txt]

                        next
                    end
                end

                # Get the link
                link = tr.xpath(".//a/@href")[0]
                sub_links[lang] = "#{YIFY}#{link}"
                @logger.debug "Lang: #{lang}, page: #{link}"
            end
            
            # If the link of a specific language is not chosen, revision the links
            source = @source.downcase
            @langs.each do |lang|
                if not sub_links[lang]
                    best_link = nil
                    links[lang].each do |link, txt|
                        best_link = best_link || link
                        if link.match(BLURAY) && source.match(BLURAY)
                            best_link = link
                        elsif link.match(WEBRIP) && source.match(WEBRIP)
                            best_link = link
                        end
                    end
                    sub_links[lang] = best_link
                end
            end

            sub_links
        end

        def _get_sub_down_links sub_page_links
            sub_down_links = {}
            sub_page_links.each do |lang, page|
                if not page
                    @logger.debug "#{lang} for #{@title} is not available"
                    next
                end
                
                @logger.debug "Going #{lang} page #{page}..."
                @driver.get page
                ele_down_link = @wait.until { @driver.find_element(:class_name, 'movie-main-info') }
                html_down_link = Nokogiri::HTML.parse ele_down_link.attribute('innerHTML')
                link = html_down_link.xpath("//a/@href")[1]
                @logger.debug "Subtitle for #{@title}, #{lang}: #{link}"
                sub_down_links[lang] = link.content
            end

            return sub_down_links
        end
    end
end


