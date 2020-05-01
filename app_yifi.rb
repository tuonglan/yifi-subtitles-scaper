require 'optparse'
require 'logger'

require_relative 'yify_scraper'
require_relative 'tools'


def download_subtitles langs, dir, logger, limit=0
    # Gather information of the directory
    downloader = Tools::SubDownloader.new(logger: logger)
    data, err = Tools::scan_dir dir
    logger.warn "Directories with no info:\n #{err}"

    # Download all subtitles for the movies
    idx = 0
    data.each do |subdir, info|
        if limit > 0 && idx >= limit
            break
        else
            idx += 1
        end

        logger.info " ---- Searching sub #{langs} for \"#{info['name']}\"... ----"
        scraper = Yify::SubScraper.new(info['name'], langs, info['year'], 0, info['source'], logger: logger)
        sub_page_links = scraper.get_sub_links
        if not sub_page_links
            #logger.error "Can't search subtitles for #{info['name']}"
            next
        end

        # Download the subtitle
        video_file = nil
        Dir.entries(File.join(dir, subdir)).each do |f|
            if f.end_with?('.mp4', '.mkv', '.avi')
                video_file = File.join(dir, subdir, f)
                break
            end
        end
        if not video_file
            logger.warning "Directory #{subdir} has no video file, skipp it"
            next
        end
        sub_page_links.each do |lang, link|
            logger.info "Downloading #{lang} for #{info['name']} at #{link}..."
            downloader.down(link, video_file, lang)
        end
    end
end


if __FILE__ == $0
    options = {
        dir: nil,
        langs: ['English', 'Vietnamese'],
        limit: 0,
        log_level: Logger::INFO
        }
    OptionParser.new do |opts|
        opts.on('-l', '--link L', "Specify download link") {|l| options[:link] = l}
        opts.on('-L', '--langs', "Specify language") {|l| options[:lang] = l.split(',')}
        opts.on('-d', '--dir D', "Specify the directory") {|d| options[:dir] = d}
        opts.on('-n', '--limit l', "Specify limit of scanning") {|l| options[:limit] = l.to_i}
        opts.on('--log_level L', "Specify the log level of the test") do |l|
            options[:log_level] = Logger::ERROR if l == 'error'
            options[:log_level] = Logger::WARN if l == 'warning'
            options[:log_level] = Logger::DEBUG if l == 'debug'
        end
    end.parse!
    
    # Init the logger
    logger = Logger.new(STDOUT)
    logger.level = options[:log_level]
    logger.datetime_format = "%Y-%m-%d %H:%M:%S"

    download_subtitles(options[:langs], options[:dir], logger, options[:limit])
end
