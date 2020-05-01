require 'logger'
require 'optparse'
require 'pp'

require_relative 'tools'

def test_down link, path, lang, logger
    logger.info("Downloading subtitle...")
    downloader = Tools::SubDownloader.new(logger: logger)
    downloader.down(options[link], options[path], options[lang])
end

def test_dir dir, logger
    logger.info "Scanning the directory..."
    data, err = Tools.scan_dir dir
    logger.info "Successfully scanned:"
    pp data
    logger.info "Failed to scan:"
    pp err
end

if __FILE__ == $0
    options = {
        link: nil,
        lang: nil,
        path: nil,
        dir: nil,
        log_level: Logger::INFO
    }
    OptionParser.new do |opts|
        opts.on('-l', '--link L', "Specify download link") {|l| options[:link] = l}
        opts.on('-L', '--lang L', "Specify language") {|l| options[:lang] = l}
        opts.on('-p', '--path P', "Specify mp4 path") {|p| options[:path] = p}
        opts.on('-d', '--dir D', "Specify the directory") {|d| options[:dir] = d}
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

    # Test down
    # test_down(options[:link], options[:path], options[:lang], logger)

    # Test dir
    test_dir(options[:dir], logger)
end
