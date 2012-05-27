module GeekTestMacros
  module Controllers
    def self.extended(base)
      base.extend ModelIntrospections

      base.send :include, ModelIntrospections
      base.send :include, Assertions
    end

    def should_get(action, options = {}, &test_body)
      as = options.delete(:as) || :html
      on = options.delete(:on)

      path = [model_name.pluralize, on, action.to_s].compact
      test "GET /#{path.join('/')} as #{as}" do
        request.env["HTTP_ACCEPT"] = Mime[as]

        if on.is_a? Symbol
          get action, id: find_fixture_for(on, described_model).to_param
        else
          get action
        end

        assert_response :success
        assert_equal Mime[as], response.content_type

        instance_eval &test_body if block_given?
      end
    end

    def should_get_resources(options = {}, &test_body)
      should_get :index, options do
        assigned_resource = assigns(model_name.pluralize.to_sym)
        assert_not_nil assigned_resource
        assert_equal described_model.all, assigned_resource

        instance_eval &test_body if block_given?
      end
    end

    def should_get_resource(record, options = {}, &test_body)
      should_get :show, options.merge(on: record) do
        fixture = find_fixture_for(record, described_model)

        assigned_resource = assigns(model_name.to_sym)
        assert_not_nil assigned_resource
        assert_equal fixture, assigned_resource

        instance_eval &test_body if block_given?
      end
    end

    def should_create_resource(options = {}, &test_body)
      params = options[:params]
      format = options[:as] || :html
      test "POST /#{model_name.pluralize} as #{format}" do
        request.env["HTTP_ACCEPT"] = Mime[format]
        assert_difference "#{described_model.name}.count" do
          post :create, params
        end

        assert_equal Mime[format], response.content_type
        assert_not_nil assigns(model_name.to_sym)

        instance_eval &test_body if block_given?
      end
    end

    def should_update_resource(record, options = {}, &test_body)
      params = options[:params]
      format = options[:as] || :html
      test "PUT /#{model_name.pluralize}/XXX as #{format}" do
        record = find_fixture_for(record, described_model) if
          record.is_a? Symbol

        request.env["HTTP_ACCEPT"] = Mime[format]
        assert_no_difference "#{described_model.name}.count" do
          put :update, params.merge(:id => record.to_param)
        end

        assert_equal Mime[format], response.content_type
        assert_not_nil assigns(model_name.to_sym)

        instance_eval &test_body if block_given?
      end
    end

    def should_fail_on_create_resource(options = {}, &test_body)
      params = options[:params]
      format = options[:as] || :html
      test "POST /#{model_name.pluralize} as #{format} with invalid params" do
        request.env["HTTP_ACCEPT"] = Mime[format]
        assert_no_difference "#{described_model.name}.count" do
          post :create, params
        end

        assert_equal Mime[format], response.content_type
        assert_not_nil assigns(model_name.to_sym)

        instance_eval &test_body if block_given?
      end
    end

    def should_fail_on_update_resource(record, options = {},
                                       &test_body)
      params = options[:params]
      format = options[:as] || :html
      test "PUT /#{model_name.pluralize} as #{format} with invalid params" do
        record = find_fixture_for(record, described_model) if
          record.is_a? Symbol

        request.env["HTTP_ACCEPT"] = Mime[format]
        assert_no_difference "#{described_model.name}.count" do
          put :update, params.merge(:id => record.to_param)
        end

        assert_equal Mime[format], response.content_type
        assert_not_nil assigns(model_name.to_sym)

        instance_eval &test_body if block_given?
      end
    end

    def should_destroy_resource(record, options = {}, &test_body)
      format = options[:as] || :html
      test "DELETE /#{model_name.pluralize}/XXX as #{format}" do
        record = find_fixture_for(record, described_model) if
          record.is_a? Symbol

        request.env["HTTP_ACCEPT"] = Mime[format]
        assert_difference "#{described_model.name}.count", -1 do
          delete :destroy, :id => record.to_param
        end

        assert_equal Mime[format], response.content_type
        assert_not_nil assigns(model_name.to_sym)

        instance_eval &test_body if block_given?
      end
    end

    protected
    module ModelIntrospections
      def model_name; described_model.name.underscore; end

      def described_model
        return described unless described < ApplicationController

        @described_model ||= described.name.gsub(/Controller$/, '')
          .split('::')
          .reduce(Object) do |parent, local_name|
          parent.const_get(local_name.singularize)
        end
      end
    end

    module Assertions
      def assert_action_title(*titles)
        assert_select 'title', titles.join(' | ')
        project = titles.shift if titles.size > 1

        assert_select 'h1', titles.join(' | ')
      end

      # assert_error_explains_for title: :blank
      # assert_error_explains_for title: [:blank, :uniqueness]
      def assert_error_explains_for(attrs_and_validations = {})
        assert_select '#error_explanation' do
          attrs_and_validations.each do |attr, validaton_messages|
            [*validaton_messages].each do |validation_message|
              message = error_message_for(validation_message)
              assert_select 'li', "#{attr.to_s.humanize} #{message}"
            end
          end
        end
      end

      def assert_form(action, options = {}, &block)
        method = options[:method] || :post

        if method == :put || method == :delete
          _method, method = method, :post
          test_body = Proc.new do
            assert_input :hidden, name: '_method', value: _method
            block.call if block
          end
        else
          test_body = block
        end

        assert_select "form#{selector_for(action: action, method: method)}",
        &test_body
      end

      def assert_form_element(attr, options = {})
        dom_id   = "#{model_name}_#{attr}"
        dom_name = "#{model_name}[#{attr}]"

        assert_select options[:wrapper] || 'p' do
          assert_select "label[for=#{dom_id}]"

          type = options.delete(:type)
          options.merge!(:id => dom_id, :name => dom_name)
          if type == :textarea
            text = options.delete(:text)
            if text.blank?
              assert_select "#{type}#{selector_for(options)}"
            else
              assert_select "#{type}#{selector_for(options)}", text
            end
          elsif type == :date_select
            assert_date_select attr, options
          else
            assert_input type, options
          end
        end
      end

      def assert_date_select(attr, options = {})
        value = options.delete(:value)

        # Year
        assert_select_box options.merge(name_id_pair(attr, '1i')) do
          assert_selected_option value.year if value
        end

        # Month
        assert_select_box options.merge(name_id_pair(attr, '2i')) do
          assert_selected_option value.month,
          I18n.t("date.month_names")[value.month] if value
        end

        # Day
        assert_select_box options.merge(name_id_pair(attr, '3i')) do
          assert_selected_option value.day if value
        end
      end

      def assert_selected_option(value, text = value.to_s)
        assert_select("option[selected=selected][value=#{value}]", text)
      end

      def assert_input(type, options = {})
        selector = selector_for(options.merge(:type => type))
        assert_select "input#{selector}"
      end

      def assert_select_box(options = {}, &block)
        assert_select "select#{selector_for(options)}", &block
      end

      def selector_for(options = {})
        id        = options.delete(:id)
        classes   = [*options.delete(:classes)]
          .compact.collect{|c| ".#{c}" }.join

        attributes = options.collect{|k, v|
          "[#{k}='#{v}']" }.join

        "#{id ? '#' + id : ''}#{classes}#{attributes}"
      end

      def name_id_pair(attr, sufix = nil)
        isufix = sufix ? "_#{sufix}"  : ''
        nsufix = sufix ? "(#{sufix})" : ''

        { name: "#{model_name}[#{attr}#{nsufix}]",
          id: "#{model_name}_#{attr}#{isufix}" }
      end
    end
  end
end
