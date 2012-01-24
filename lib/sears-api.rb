require 'httparty'
require 'ick'
require 'active_support/inflector/methods'
require 'ostruct'

module SearsApi

  class Configuration
    class << self
      attr_accessor :key
    end

  end


  class Client
    include HTTParty
    base_uri 'http://api.developer.sears.com/v1/'

    class << self

      def kget(path,opt = {})
        opt[:query] ||= {}
        opt[:query].merge!({:apikey => SearsApi::Configuration.key, 
                            :store  => 'Sears'}) {|k,v1,v2| v1}
        Response.new(get(path, opt))
      end

      def product_details(part_number, opt = {})
        kget('/productdetails', :query => {:partNumber => part_number}.merge(opt))
      end
      
      def product_search_by_keyword(keyword, opt = {})
        kget('/productsearch', 
             :query => {:keyword => keyword,:searchType => 'keyword'}.
             merge(opt))
      end

      # for each foo in the first array create methods prefixed with 
      # the store names like kmart_foo, mygofer_foo, sears_foo
      # although sears_foo == foo
      [:product_search_by_keyword, :product_details].each do |meth|
        %w[kmart mygofer sears].each do |store_name|
          define_method("#{store_name}_#{meth.to_s}".to_sym) do |keyword|
            send(meth.to_sym, keyword, :store => store_name.capitalize)
          end
        end
      end

    end

  end

  module MethodMissingDeligation

    def method_missing(sym)
      res = Ick::Try.instance.invoke (deligate) {|x| x.send(sym)}
      res ||= Ick::Try.instance.invoke (deligate) {|x| x.send(ActiveSupport::Inflector.camelize(sym.to_s).to_sym) }
      res ||= super
    end

  end

  class Response

    attr_accessor :resp, :deligate

    include MethodMissingDeligation

    def initialize(resp)
      @resp = resp
      self.extend Search if Ick::Try.instance.invoke(resp) {|x| x.first.first} == "MercadoResult"
      self.extend ProductDetails if Ick::Try.instance.invoke(resp) {|x| x.first.first} == "ProductDetail"
    end

  end

  module Search
    def deligate
      resp.first[1]['Products']['Product'].map {|x| Record.new(OpenStruct.new(x))}
    end
  end

  module ProductDetails
    def deligate
      Record.new(OpenStruct.new(resp.first[1]['SoftHardProductDetails']))
    end
  end

  Record = Struct.new(:deligate) do
    include  MethodMissingDeligation
  end

end
