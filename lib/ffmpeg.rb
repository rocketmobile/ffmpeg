require "ffmpeg/version"
require "paperclip"
require "streamio-ffmpeg"

module Paperclip
  class Ffmpeg < Processor
    attr_accessor :current_geometry, :target_geometry, :format,
                  :basename, :time, :rotation

    def initialize(file, options = {}, attachment = nil)
      super

      geometry             = options[:geometry].to_s
      @file                = file
      @crop                = geometry[-1,1] == '#'
      @target_geometry     = options.fetch(:string_geometry_parser, Geometry).parse(geometry)
      @current_geometry    = options.fetch(:file_geometry_parser, Geometry).from_file(@file)
      @convert_options     = options[:convert_options]
      @whiny               = options.fetch(:whiny, true)
      @format              = options[:format]
      @auto_rotate         = options.fetch(:auto_rotate, true)
      @time                = options.fetch(:time, 1)
      @rotation            = calculate_rotation
      @pad_color           = options.fetch(:pad_color, "black")

      @current_format      = File.extname(@file.path)
      @basename            = File.basename(@file.path, @current_format)
    end

    # Performs the transcoding of the +file+ into a thumbnail/video. Returns the Tempfile
    # that contains the new image/video.
    def make
      src = file
      dst = Tempfile.new([basename, format ? ".#{format}" : ''])
      dst.binmode

      parameters = []
      parameters << "-ss  #{time}" if output_is_image?
      parameters << "-i :source"
      parameters << "-vframes 1"
      parameters << "-vf " + transformation_command
      parameters << ":dest"
      parameters = parameters.flatten.compact.join(" ").strip.squeeze(" ")

      begin
        Paperclip.run("ffmpeg", parameters, source: File.expand_path(src.path), dest: File.expand_path(dst.path))
      rescue Cocaine::ExitStatusError => e
        raise Paperclip::Error, "There was an error processing the thumbnail for #{basename}"
      rescue Cocaine::CommandNotFoundError => e
        raise Paperclip::Errors::CommandNotFoundError.new("Could not run the `ffmpeg` command. Please install Ffmpeg.")
      end

      dst
    end

    private

    def transformation_command
      # '"transpose=2, scale=410:ih*410/iw, crop=410:410"'
      trans = '"'
      trans << filter_rotate(rotation) if rotate?
      trans << "scale=#{target_geometry.width}:ih*#{target_geometry.height}/iw,"
      trans << "crop=#{target_geometry.width}:#{target_geometry.height}"
      trans << '"'
      trans
    end

    def log(message)
      Paperclip.log "[ffmpeg] #{message}"
    end

    def output_is_image?
      !!format.to_s.match(/jpe?g|png|gif$/)
    end

    def filter_rotate(rotation)
      case rotation
        when 90
          "transpose=1,"
        when 180
          "vflip,hflip,"
        when 270
          "transpose=2,"
      end
    end

    def rotate?
      !!rotation
    end

    def calculate_rotation
      FFMPEG::Movie.new(file.path).rotation rescue nil
    end
  end
end
