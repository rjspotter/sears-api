require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require "ostruct"

describe "SearsApi" do

  describe "Configuration" do
    it "has a key" do
      SearsApi::Configuration.key         = "ooof"
      SearsApi::Configuration.key.should == "ooof"
    end
  end

  describe "Client" do
    
    subject {SearsApi::Client}

    it "includes HTTParty" do
      subject.included_modules.should include(HTTParty)
    end

    it "has the correct base url" do
      subject.base_uri.should == "http://api.developer.sears.com/v1"
    end

    it "returns a custom response object" do
      subject.stub(:get) { [] }
      subject.kget('/foo').class.should == SearsApi::Response
    end

    context "query defaults" do
      
      before   {SearsApi::Configuration.stub(:key) {'apikey'}}
      let(:qr) {{
          :apikey => 'apikey', 
          :store => 'Sears', 
          :partNumber => '0'}}
      
      it "adds the key and store to the query" do
        subject.should_receive(:get).with('/productdetails', :query => qr)
        subject.kget('/productdetails', :query => {:partNumber => '0'})
      end

      it "adds the query to the opts if it doesn't exist" do
        subject.should_receive(:get) {|p,o| o[:query].should_not be_nil}
        subject.kget('/productdetails')        
      end

      it "allows for overridding key and store" do
        override_hsh = {
          :apikey => 'key', 
          :store => 'Kmart', 
          :partNumber => '42'}
        subject.should_receive(:get).with('/productdetails', 
                                          :query => override_hsh)
        subject.kget('/productdetails', :query => override_hsh.clone)
      end

    end

    context "store locator" do
      it "takes a zipcode" do
        subject.should_receive(:kget).
          with('/StoreLocator', :query => {:zipCode => '94132'})
        subject.store_locator('94132')
      end

      it "takes an override" do
        subject.should_receive(:kget).
          with('/StoreLocator', :query => {:zipCode => '94132', :stateCode => 'CA'})
        subject.store_locator('94132', {:stateCode => 'CA'})
      end
    end

    context "product details" do
      it "searches by partnumber" do
        subject.should_receive(:kget).
          with('/productdetails', :query => {:partNumber => 'asdf'})
        subject.product_details('asdf')
      end
      it "has overrides by prefix" do
        subject.should_receive(:kget).
          with('/productdetails', :query => {:partNumber => 'asdf',
               :store => 'Kmart'})
        subject.kmart_product_details('asdf')
      end
    end

    context "product search" do
      
      it "searches by keyword" do
        subject.should_receive(:kget).with('/productsearch',
                                           :query => {
                                             :searchType => 'keyword',
                                             :keyword    => 'asdf'})
        subject.product_search_by_keyword('asdf')
      end

      it "allows overrides" do
        subject.should_receive(:kget).with('/productsearch',
                                           :query => {
                                             :store      => 'Kmart',
                                             :searchType => 'keyword',
                                             :keyword    => 'asdf'})
        subject.product_search_by_keyword('asdf', :store => 'Kmart')
      end

      it "takes the store prefix kmart" do
        subject.should_receive(:product_search_by_keyword).
          with('asdf', :store => 'Kmart')
        subject.kmart_product_search_by_keyword('asdf')
      end

      it "takes the store prefix mygofer" do
        subject.should_receive(:product_search_by_keyword).
          with('asdf', :store => 'Mygofer')
        subject.mygofer_product_search_by_keyword('asdf')
      end

    end

    context "current promotions" do
      it "calls kget to CurrentPromotions" do
        subject.should_receive(:kget).
          with('/CurrentPromotions', :query => {:storeName => 'Sears'})
        subject.current_promotions
      end
      it "takes an opt hash" do
        subject.should_receive(:kget).
          with('/CurrentPromotions', :query => {:sortFlag => true, :storeName => 'Sears'})
        subject.current_promotions(:sortFlag => true)
      end
      it "hides the api inconsistancy" do
        subject.should_receive(:kget).
          with('/CurrentPromotions', :query => {:sortFlag => true, :storeName => 'Kmart', :store => 'Kmart'})
        subject.current_promotions(:sortFlag => true, :store => 'Kmart')
      end
    end

  end

  describe "Response" do

    subject {SearsApi::Response}

    before  {@resp = stub.as_null_object}

    it "takes a generic response and interns it" do
      subject.new(@resp).resp.should == @resp
    end

    it "is extended with MercadoResult if needed" do
      @resp.stub_chain(:first,:first).and_return("MercadoResult")
      subject.new(@resp).singleton_class.included_modules.
        should include(SearsApi::MercadoResult)
    end

    it "is extended with ProductDetail if needed" do
      @resp.stub_chain(:first,:first).and_return("ProductDetail")
      subject.new(@resp).singleton_class.included_modules.
        should include(SearsApi::ProductDetail)
    end

    it "is extended with showStoreLocator if needed" do
      @resp.stub_chain(:first,:first).and_return("showStoreLocator")
      subject.new(@resp).singleton_class.included_modules.
        should include(SearsApi::ShowStoreLocator)
    end

    describe "instance" do

      subject {SearsApi::Response.new(@resp)}

      it "calls the delegate" do
        subject.deligate = stub
        subject.deligate.should_receive(:foo_bar_baz).and_return("foo")
        subject.foo_bar_baz
      end

      it "calls the deligate with the camelized version" do
        subject.deligate = stub
        subject.deligate.stub(:foo_bar_baz) {nil}
        subject.deligate.should_receive(:FooBarBaz).and_return('foo')
        subject.foo_bar_baz
      end

      it "raises if it doesn't exist" do
        subject.deligate = stub()
        expect {subject.foo_bar}.to raise_error
      end

    end

  end

  describe "MercadoResult Results Mixin" do
    
    subject do
      s = OpenStruct.new(:resp => stub)
      s.extend(SearsApi::MercadoResult)
      s
    end

    it "creates a deligate" do
      ex = {:foo => 'bar'}
      subject.resp.stub_chain(:first,:[],:[],:[]).and_return([ex])
      OpenStruct.should_receive(:new).with(ex)
      subject.deligate
    end

  end

  describe "Product Details Mixin" do

    subject do
      s = OpenStruct.new(:resp => stub)
      s.extend(SearsApi::ProductDetail)
      s
    end

    it "creates a deligate" do
      ex = {:foo => 'bar'}
      subject.resp.stub_chain(:first,:[],:[]).and_return(ex)
      OpenStruct.should_receive(:new).with(ex)
      subject.deligate
    end

  end

  describe "PromotionDetails Mixin" do
    subject do
      s = OpenStruct.new(:resp => stub)
      s.extend(SearsApi::PromotionDetails)
      s
    end

    it "creates a deligate" do
      ex = {:foo => 'bar'}
      subject.resp.stub_chain(:first,:[],:[]).and_return([ex])
      OpenStruct.should_receive(:new).with(ex)
      subject.deligate      
    end
  end

  describe "ShowStoreLocator Mixin" do
    
    subject do
      s = OpenStruct.new(:resp => stub)
      s.extend(SearsApi::ShowStoreLocator)
      s
    end

    it "creates a deligate" do
      ex = {:foo => 'bar'}
      subject.resp.stub_chain(:first,:[],:[],:[]).and_return([ex])
      OpenStruct.should_receive(:new).with(ex)
      subject.deligate
    end

  end
end
