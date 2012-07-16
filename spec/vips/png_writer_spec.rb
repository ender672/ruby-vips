require "spec_helper"

describe VIPS::PNGWriter do
  before :all do
    @image = simg 'wagon.v'
    @writer = VIPS::PNGWriter.new @image
    @path = tmp('wagon.png').to_s
  end

  pending "should write to a png file" do
    @writer.write @path

    im = VIPS::Image.png @path
    im.x_size.should == @image.x_size
    im.y_size.should == @image.y_size
  end

  pending "should write a png to memory" do
    if Spec::Helpers.match_vips_version("> 7.22")
      str = @writer.to_memory
      str.size.should == 54804
    else
      lambda{ @writer.to_memory }.should raise_error(VIPS::Error)
    end
  end

  pending "should write a tiny png file to memory" do
    if Spec::Helpers.match_vips_version("> 7.22")
      im = VIPS::Image.black(10, 10, 1)
      s = im.png.to_memory
      s.size.should == 69
    end
  end

  it "should allow setting of the png compression" do
    @writer.compression = 9
    @writer.compression.should == 9
  end

  it "should raise an exception when trying to set an invalid compression" do
    lambda{ @writer.compression = -2 }.should raise_error(ArgumentError)
    lambda{ @writer.compression = "abc" }.should raise_error(ArgumentError)
    lambda{ @writer.compression = 3333 }.should raise_error(ArgumentError)
  end

  it "should generate smaller memory images with higher compression settings" do
    if Spec::Helpers.match_vips_version("> 7.22")
      @writer.compression = 0
      mempng = @writer.to_memory

      @writer.compression = 9
      mempng2 = @writer.to_memory

      mempng2.size.should < mempng.size / 2
    end
  end

  it "should write smaller images with lower quality settings" do
    @writer.compression = 9
    @writer.write(@path)
    size1 = File.size @path

    @writer.compression = 0
    @writer.write(@path)
    size2 = File.size @path

    size1.should < size2 / 2
  end

  pending "should write an interlaced png" do
    @writer.interlace = true
    @writer.write @path

    im = VIPS::Image.png(@path)
    im.should match_image(@image)
  end

  it "should write an interlaced png to memory" do
    if Spec::Helpers.match_vips_version("> 7.22")
      @writer.interlace = true
      str = @writer.to_memory
    end
  end

  it "should create a png writer" do
    @writer.class.should == VIPS::PNGWriter
    @writer.image.should == @image
  end

  it "should accept options on creation from an image" do
    writer = @image.png(nil, :compression => 3, :interlace => true)
    writer.compression.should == 3
    writer.interlace.should be_true
  end
end
