require "ffmpeg/version"
require "paperclip"

module Paperclip
  class Ffmpeg < Processor
    # Creates a Video object set to work on the +file+ given. It
    # will attempt to transcode the video into one defined by +target_geometry+
    # which is a "WxH"-style string. +format+ should be specified.
    # Video transcoding will raise no errors unless
    # +whiny+ is true (which it is, by default. If +convert_options+ is
    # set, the options will be appended to the convert command upon video transcoding.
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
      @auto_orient         = options.fetch(:auto_orient, true)
      @time                = options[:time].fetch(:time, 1)
      @pad_color           = options[:pad_color].fetch(:pad_color, "black")
      if @auto_orient && @current_geometry.respond_to?(:auto_orient)
        @current_geometry.auto_orient
      end

      @source_file_options = @source_file_options.split(/\s+/) if @source_file_options.respond_to?(:split)
      @convert_options     = @convert_options.split(/\s+/)     if @convert_options.respond_to?(:split)

      @cli                 = ::Av.cli

      @current_format   = File.extname(@file.path)
      @basename         = File.basename(@file.path, @current_format)
      attachment.instance_write(:meta, @meta) if attachment
    end

    # Performs the transcoding of the +file+ into a thumbnail/video. Returns the Tempfile
    # that contains the new image/video.
    def make
      ::Av.logger = Paperclip.logger
      @cli.add_source @file
      dst = Tempfile.new([@basename, @format ? ".#{@format}" : ''])
      dst.binmode

      if @meta
        log "Transcoding supported file #{@file.path}"
        @cli.add_source(@file.path)
        @cli.add_destination(dst.path)
        @cli.reset_input_filters

        if output_is_image?
          @time = @time.call(@meta, @options) if @time.respond_to?(:call)
          @cli.filter_seek @time
        end

        if @convert_options.present?
          if @convert_options[:input]
            @convert_options[:input].each do |h|
              @cli.add_input_param h
            end
          end
          if @convert_options[:output]
            @convert_options[:output].each do |h|
              @cli.add_output_param h
            end
          end
        end

        begin
          @cli.run
          log "Successfully transcoded #{@basename} to #{dst}"
        rescue Cocaine::ExitStatusError => e
          raise Paperclip::Error, "error while transcoding #{@basename}: #{e}" if @whiny
        end
      else
        log "Unsupported file #{@file.path}"
        # If the file is not supported, just return it
        dst << @file.read
        dst.close
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

  class Attachment
    def meta
      instance_read(:meta)
    end
  end
end
