require "spec_helper"

describe Paperclip::Ffmpeg do
  let(:android_video) { File.new(Dir.pwd + "/spec/support/assets/android.mp4") }
  let(:iphone_video)  { File.new(Dir.pwd + "/spec/support/assets/iphone.mp4") }

  describe "thumbnail" do
    it "does some stuff" do
      video = Video.new(asset: android_video)
      video.save
    end
  end
end
