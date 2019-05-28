module Mws::Apis::Feeds
  class Product
    CategorySerializer = Mws::Serializer.new ce: 'CE', fba: 'FBA', eu_compliance: 'EUCompliance'

    attr_reader :sku, :description

    attr_accessor :upc, :upc_type, :tax_code, :msrp, :brand, :manufacturer,
                  :name, :description, :bullet_points, :item_type, :launch_date,
                  :item_dimensions, :package_dimensions, :package_weight,
                  :shipping_weight, :category, :category_data, :details,
                  :condition_type, :mfr_part_number, :search_terms,
                  :used_fors, :other_item_attributes, :target_audiences,
                  :recommended_browse_nodes, :variation_data,
                  :release_date, :classification_data

    def initialize(sku, &block)
      @sku = sku
      @bullet_points = []
      @search_terms = []
      @used_fors = []
      @other_item_attributes = []
      @target_audiences = []
      @category_data = {}
      @recommended_browse_nodes = []

      ProductBuilder.new(self).instance_eval &block if block_given?

      if @details.present? && @category.blank?
        raise Mws::Errors::ValidationError, 'Product must have a category when details are specified.'
      end
    end

    def to_xml(name = 'Product', parent = nil)
      Mws::Serializer.tree name, parent do |xml|
        xml.SKU @sku
        xml.StandardProductID {
          xml.Type @upc_type || 'UPC'
          xml.Value @upc
        } unless @upc.nil?

        xml.ProductTaxCode @tax_code unless @upc.nil?
        xml.LaunchDate @launch_date unless @launch_date.nil?
        xml.ReleaseDate @release_date unless @release_date.nil?
        xml.Condition {
          xml.ConditionType @condition_type
        } unless @condition_type.nil?

        xml.DescriptionData {
          xml.Title @name unless @name.nil?
          xml.Brand @brand  unless @brand.nil?
          xml.Description @description  unless @description.nil?
          Array(bullet_points).each do |bullet_point|
            xml.BulletPoint bullet_point
          end
          @item_dimensions.to_xml('ItemDimensions', xml) unless @item_dimensions.nil?
          @package_dimensions.to_xml('PackageDimensions', xml) unless @item_dimensions.nil?

          @package_weight.to_xml('PackageWeight', xml) unless @package_weight.nil?
          @shipping_weight.to_xml('ShippingWeight', xml) unless @shipping_weight.nil?

          @msrp.to_xml 'MSRP', xml unless @msrp.nil?

          xml.Manufacturer @manufacturer unless @manufacturer.nil?
          xml.MfrPartNumber @mfr_part_number unless mfr_part_number.nil?
          Array(search_terms).each do |search_term|
            xml.SearchTerms search_term
          end
          Array(used_fors).each do |used_for|
            xml.UsedFor used_for
          end
          xml.ItemType @item_type unless @item_type.nil?

          Array(other_item_attributes).each do |other_item_attribute|
            xm.OtherItemAttributes other_item_attribute
          end

          Array(target_audiences).each do |target_audience|
            xm.TargetAudience target_audience
          end

          Array(recommended_browse_nodes).each do |recommended_browse_node|
            xm.RecommendedBrowseNode recommended_browse_node
          end
        }

        @category_data ||= {}
        @category_data[:product_type] = @details if @details.present?
        @category_data[:variation_data] = @variation_data if @variation_data.present?
        @category_data[:classification_data] = @classification_data if @classification_data.present?

        xml.ProductData {
          CategorySerializer.xml_for @category, @category_data, xml
        } if @category_data.present?
      end
    end

    class DelegatingBuilder
      def initialize(delegate)
        @delegate = delegate
      end

      def method_missing(method, *args, &block)
        # Writer method proxy
        if @delegate.respond_to? "#{method}="
          @delegate.send("#{method}=", *args, &block)

        # Arbritrary data nodes
        elsif @delegate.respond_to? :[] # Node builder
          if block_given?
            @delegate[method] = {}
            self.class.new(@delegate[method]).instance_eval(&block)
          elsif args.present?
            @delegate[method] = args.first
          end

        # Definitely unknown
        else
          super
        end
      end
    end

    class ProductBuilder < DelegatingBuilder
      def msrp(amount, currency)
        @delegate.msrp = Money.new amount, currency
      end

      def item_dimensions(&block)
        @delegate.item_dimensions = Dimensions.new
        DimensionsBuilder.new(@delegate.item_dimensions).instance_eval &block if block_given?
      end

      def package_dimensions(&block)
        @delegate.package_dimensions = Dimensions.new
        DimensionsBuilder.new(@delegate.package_dimensions).instance_eval &block if block_given?
      end

      def package_weight(value, unit = nil)
        @delegate.package_weight = Weight.new(value, unit)
      end

      def shipping_weight(value, unit = nil)
        @delegate.shipping_weight = Weight.new(value, unit)
      end

      def bullet_point(bullet_point)
        # Max 5
        @delegate.bullet_points ||= []
        @delegate.bullet_points << bullet_point
      end

      def search_term(search_term)
        # Max 5
        @delegate.search_terms ||= []
        @delegate.search_terms << search_term
      end

      def used_for(used_for)
        # Max 5
        @delegate.used_fors ||= []
        @delegate.used_fors << used_for
      end

      def other_item_attribute(other_item_attribute)
        # Max 5
        @delegate.other_item_attributes ||= []
        @delegate.other_item_attributes << other_item_attribute
      end

      def target_audience(target_audience)
        # Max 4
        @delegate.target_audiences ||= []
        @delegate.target_audiences << target_audience
      end

      def recommended_browse_node(recommended_browse_node)
        # Max 2 (EUR only)
        @delegate.recommended_browse_nodes << recommended_browse_node
      end

      def details(details = nil, &block)
        @delegate.details = details || {}
        DetailBuilder.new(@delegate.details).instance_eval &block if block_given?
      end

      def variation_data(data = nil, &block)
        @delegate.variation_data = data || {}
        DelegatingBuilder.new(@delegate.variation_data).instance_eval &block if block_given?
      end

      def classification_data(data = nil, &block)
        @delegate.classification_data = data || {}
        DelegatingBuilder.new(@delegate.classification_data).instance_eval &block if block_given?
      end
    end

    class Dimensions
      attr_accessor :length, :width, :height, :weight

      def to_xml(name = 'Dimensions', parent = nil)
        Mws::Serializer.tree name, parent do |xml|
          @length.to_xml 'Length', xml unless @length.nil?
          @width.to_xml 'Width', xml unless @width.nil?
          @height.to_xml 'Height', xml unless @height.nil?
          @weight.to_xml 'Weight', xml unless @weight.nil?
        end
      end
    end

    class DimensionsBuilder < DelegatingBuilder
      def length(value, unit = nil)
        @delegate.length = Distance.new(value, unit)
      end

      def width(value, unit = nil)
        @delegate.width = Distance.new(value, unit)
      end

      def height(value, unit = nil)
        @delegate.height = Distance.new(value, unit)
      end

      def weight(value, unit = nil)
        @delegate.weight = Weight.new(value, unit)
      end
    end

    class DetailBuilder < DelegatingBuilder
      def as_distance(amount, unit = nil)
        Distance.new amount, unit
      end

      def as_weight(amount, unit = nil)
        Weight.new amount, unit
      end

      def as_money(amount, currency = nil)
        Money.new amount, currency
      end
    end
  end
end
