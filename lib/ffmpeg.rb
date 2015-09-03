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


      parameters = []
      # parameters << source_file_options
      parameters << "-ss 1 -i :source"
      # parameters << transformation_command
      # parameters << convert_options
      parameters << "-qscale:v 2 -vframes 1 :dest"
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

    def transformation_command
      # scale, crop = @current_geometry.transformation_to(@target_geometry, crop?)
      trans = []
      # trans << "-coalesce" if animated?
      # trans << "-auto-orient" if auto_orient
      # trans << "-resize" << %["#{scale}"] unless scale.nil? || scale.empty?
      # trans << "-crop" << %["#{crop}"] << "+repage" if crop
      # trans << '-layers "optimize"' if animated?
      trans
    end

    def log(message)
      Paperclip.log "[ffmpeg] #{message}"
    end

    def output_is_image?
      !!@format.to_s.match(/jpe?g|png|gif$/)
    end

    def whiny?
      whiny
    end
  end
end
