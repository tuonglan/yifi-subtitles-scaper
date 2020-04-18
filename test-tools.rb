require 'logger'
require 'optparse'

require_relative 'tools'


if __FILE__ == $0
    options = {
        link: nil,
        lang: nil,
        path: nil,
        log_level: Logger::INFO
    }
    OptionParser.new do |opts|
        opts.on('-l', '--link L', "Specify download link") {|l| options[:link] = l}
        opts.on('-L', '--lang L', "Specify language") {|l| options[:lang] = l}
        opts.on('-p', '--path P', "Specify mp4 path") {|p| options[:path] = p}
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
    
    logger.info("Downloading subtitle...")
    downloader = Tools::SubDownloader.new(logger: logger)
    downloader.down(options[:link], options[:path], options[:lang])
end
