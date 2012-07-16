require "spec_helper"

describe VIPS::Image do
  before :all do
    @image = simg 'wagon.v'
  end

  it "should generate the histogram for all bands in an image" do
    hist = @image.histgr
    hist.bands.should == 3
    hist.vtype.should == :HISTOGRAM
    hist.band_fmt.should == :UINT
    hist.x_size.should == 256
    hist.y_size.should == 1

    hist[120, 0].should == [167, 265, 153]
  end

  it "should generate the histogram for an image band" do
    h0 = @image.histgr(0)
    h1 = @image.histgr(1)
    h2 = @image.histgr(2)

    [h0, h1, h2].each do |hist|
      hist.bands.should == 1
      hist.vtype.should == :HISTOGRAM
      hist.band_fmt.should == :UINT
      hist.x_size.should == 256
      hist.y_size.should == 1
    end

	h0[120, 0].should == 167
	h1[120, 0].should == 265
	h2[120, 0].should == 153
  end

  it "should make a one two or three dimensional histogram" do
    pending "this segfaults and unsure how to test"
    hist = @image.histnd(1)
  end

  it "should generate a histogram from an index image" do
    pending "need a test case for this"
  end

  it "should generate an n-band lut (lookup table) identity" do
    hist = VIPS::Image.identity(2)
    hist.bands.should == 2
    hist.vtype.should == :HISTOGRAM
    hist.band_fmt.should == :UCHAR
    hist.x_size.should == 256
    hist.y_size.should == 1

	hist[200, 0].should == [200, 200]
  end
  
  it "should generate an n-band lut (lookup table) identity with upto 2^16 elements" do
    ident = VIPS::Image.identity_ushort(3, 1200)
    ident.x_size.should == 1200
    ident.bands.should == 3
    ident.band_fmt.should == :USHORT
    ident.vtype.should == :HISTOGRAM

	ident[1102, 0].should == [1102, 1102, 1102]
  end
  
  pending "should create an inverted lookup table" do
    mask = [
      [0.1, 0.2, 0.3, 0.1],
      [0.2, 0.4, 0.4, 0.2],
      [0.7, 0.5, 0.6, 0.3]
    ]

    im = VIPS::Image.invertlut mask, 2000

    im.histplot.should match_sha1('c3e791834af4f1c7edc0b1d48f7b5f7bd3acf9f4')
  end
  
  pending "should build a lookup table from a set of points", :vips_lib_version => "> 7.20" do
    mask = [
      [12, 100],
      [14, 110],
      [18, 120]
    ]

    hist = VIPS::Image.buildlut mask

    hist.bands.should == 1
    hist.vtype.should == :HISTOGRAM
    hist.band_fmt.should == :DOUBLE
    hist.y_size.should == 1

    hist.histplot.should match_sha1('c0b62e58bc701b82e0cc2ffa671a3f606bcf8ce0')
  end

  it "should calculate row sums and column sums for an image" do
    im1, im2 = @image.project

    expected_row_sum = [0, 0, 0]
    @image.x_size.times do |i|
      @image[i, 55].each_with_index{ |v, i| expected_row_sum[i] += v }
    end
    im1[0, 55].should == expected_row_sum

    expected_col_sum = [0, 0, 0]
    @image.y_size.times do |i|
      @image[99, i].each_with_index{ |v, i| expected_col_sum[i] += v }
    end

    im2[99, 0].should == expected_col_sum
  end

  it "should normalize a histogram to make it square" do
    im = @image.histgr
    im2 = im.histnorm

    im2.x_size.should == im2.max + 1
    im2.histplot.should match_sha1('c0791a82d08fa8bd529f33ab0e3e5b07a4b377e1')
  end

  it "should turn a regular histogram into a cumulative histogram" do
    im = @image.histgr
    im2 = im.histcum

    im2[20, 0][0].should == im2[19, 0][0] + im[20, 0][0]
  end

  it "should equalize a histogram by normalizing and making it cumulative", :vips_lib_version => "> 7.20" do
    im = @image.histgr.histeq
    im.should match_image(@image.histgr.histcum.histnorm)
  end

  it "should create a histogram that can make probability distribution functions identical between images" do
    image2 = simg 'huge.jpg'
    lut = @image.histgr.histspec(image2.histgr)
  end

  it "should indicate when a histogram is monotonic" do
    pending "the identity LUT should be monotonic, but isnt..."
    VIPS::Image.identity(1).monotonic?.should be_true
  end

  it "should generate a displayable histogram from an image" do
    @image.hist.should match_image(@image.histgr.histplot)
  end

  it "should make probability distribution functions identical between images" do
    image2 = simg 'huge.jpg'
    pdf_hist = @image.histgr.histspec(image2.histgr)

    @image.hsp(image2).should match_image(@image.maplut(pdf_hist))
  end

  it "should perform gamma correction on an image" do
    power = 3

    # calculate gamma corrected image manually
    ident = VIPS::Image.identity(1)
    a = ident.max**(1 - power)
    lut = ident.pow(power).lin(a, 0).clip2fmt(@image.band_fmt)
    im = @image.maplut(lut)

    @image.gammacorrect(power).should match_image(im)
  end

  it "should calculate the pixel value at the nth percentile of the image", :vips_lib_version => "> 7.20" do
    val = @image.bandmean.histgr.mpercent_hist(0.1)
    val.should == 224
  end


  it "should calculate the pixel value at the nth percentile of the image" do
    val = @image.bandmean.mpercent(0.1)
    val.should == 224
  end

  it "should perform histogram equalization on an image" do
    im = @image.heq
    im.should match_sha1('6d4a59151057e8b28236ffdf5254b77c7410b920')
  end

  it "should perform histogram on a one-band image, using the local area of each pixel to calculate" do
    im = @image.bandmean.lhisteq(60, 60)
    im.should match_sha1('a8c45d686d661156fba1bb9be8d3c714b97126ea')
  end

  it "should perform statistical differencing on an image" do
    im = @image.bandmean.scale.stdif 0.5, 128, 0.5, 50, 11, 11
    im.should match_sha1('59e6eb2dde4eb48de3aef092135057b09538d202')
  end

  it "should build a tone curve for the adjustment of color levels" do
    pending "find a way to test tone_build_range, tone_build & tone_analyze"
  end

  it "should plot a histogram" do
    im = @image.histgr.histnorm.histplot
    im.should match_sha1('c0791a82d08fa8bd529f33ab0e3e5b07a4b377e1')
  end

  it "should map a lookup table to an image" do
    lut = VIPS::Image.identity(3).lin(0.2, 30)
    im = @image.maplut(lut)

    im.should match_sha1('0825bc97cf86f8c36d31c22d36f6bec7f373383c')
  end
end

