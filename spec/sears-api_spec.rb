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

  end

  describe "Response" do

    subject {SearsApi::Response}

    before  {@resp = stub.as_null_object}

    it "takes a generic response and interns it" do
      subject.new(@resp).resp.should == @resp
    end

    it "is extended with Search if needed" do
      @resp.stub_chain(:first,:first).and_return("MercadoResult")
      subject.new(@resp).singleton_class.included_modules.
        should include(SearsApi::Search)
    end

  end

  describe "Search Results Mixin" do

    before {
      @resp = stub.as_null_object
      @s = OpenStruct.new(:resp => @resp)
      @s.extend(SearsApi::Search)
    }
    subject {@s}

    it "knows the product count" do
      expecter = stub.tap do |x|
        x.should_receive(:[]).with('ProductCount').
          and_return('161')
      end
      @resp.stub_chain(:first,:[]).and_return(expecter)
      subject.count.should == "161"
    end

    it "retuns a list of products" do
      # resp.first[1]["Products"]['Product']
      expecter = stub.tap do |x|
        x.should_receive(:[]).with('Product').
          and_return([])
      end
      @resp.stub_chain(:first,:[],:[]).and_return(expecter)
      subject.products.should == []
    end

  end

  describe "Product Details Mixin" do

    before {
      @resp = stub.as_null_object
      @s = OpenStruct.new(:resp => @resp)
      @s.extend(SearsApi::ProductDetails)
    }
    subject {@s}

    it "has a title for the product" do
      expecter = stub.tap do |x|
        x.should_receive(:[]).with('DescriptionName').
          and_return('This is a Cool Product')
      end
      @resp.stub_chain(:first,:[],:[]).and_return(expecter)
      subject.title.should == "This is a Cool Product"
    end

  end

end
