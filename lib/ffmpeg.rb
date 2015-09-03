require "ffmpeg/version"
require "paperclip"

module Paperclip
  class Ffmpeg < Processor
    attr_accessor :current_geometry, :target_geometry, :format, :whiny,
                  :auto_rotate, :basename

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

      # if output_is_image?
      #   @time = @time.call(@meta, @options) if @time.respond_to?(:call)
      #   cli.filter_seek @time
      # end
      # if auto_rotate && @meta[:rotate]
      #   cli.filter_rotate @meta[:rotate]
      # end
      # cli.add_output_param "vf", "crop=#{target_geometry.height}:#{target_geometry.width}"

      parameters << "-i :source"
      begin
        Paperclip.run("ffmpeg", parameters, source: "#{File.expand_path(src.path)}", dest: File.expand_path(dst.path))
      rescue Cocaine::ExitStatusError => e
        raise Paperclip::Error, "There was an error processing the thumbnail for #{basename}" if whiny
      rescue Cocaine::CommandNotFoundError => e
        raise Paperclip::Errors::CommandNotFoundError.new("Could not run the `ffmpeg` command. Please install Ffmpeg.")
      end

      dst
    end

    def log message
      Paperclip.log "[transcoder] #{message}"
    end

    def format_geometry geometry
      return unless geometry.present?
      return geometry.gsub(/[#!<>)]/, '')
    end

    def output_is_image?
      !!@format.to_s.match(/jpe?g|png|gif$/)
    end
  end
end
