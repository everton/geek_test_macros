require_relative 'geek_test_macros/models'
require_relative 'geek_test_macros/controllers'

module GeekTestMacros
  def self.included(base)
    base.extend GeekTestMacros::Base
    base.extend GeekTestMacros::Models
    base.extend GeekTestMacros::Controllers
  end

  def described(described = nil); self.class.described(described); end
  def find_fixture_for(register, model_class = described)
    # fixture_class_names:
    #   { :financial_posts => "FinancialPost" }
    fixture_class_names.each do |fixture_name, model_name|
      return send(fixture_name, register) if
        model_name == model_class.name
    end
  end

  def error_message_for(kind, options = {})
    kind = kind.to_sym
    if I18n.t("activerecord.errors.messages").has_key? kind
      I18n.t("activerecord.errors.messages.#{kind}", options)
    else
      I18n.t("errors.messages.#{kind}", options)
    end
  end

  # Usage:
  #   assert_bad_value(:foo, 'bar', 'Bar not valid for foo')
  #   assert_bad_value(:foo, 'bar', :invalid, 'Are not validating')
  def assert_bad_value(attr, value, validation_msg, fail_msg = nil)
    validation_msg = error_message_for(validation_msg) if
      validation_msg.is_a? Symbol

    fail_msg ||= "#{described.name} with #{attr} '#{value}'" +
      " expected to be invalid"

    subject = described.new
    subject.send("#{attr}=", value)

    refute subject.valid?, fail_msg
    assert_includes subject.errors[attr], validation_msg
  end

  # Usage:
  #   assert_good_value(:foo, 'bar')
  #   assert_good_value(:foo, 'bar', 'Bar not valid on foo')
  def assert_good_value(attr, value, fail_msg = nil)
    subject = described.new
    subject.send("#{attr}=", value)

    subject.valid? # just validates it, don't assert about this,
    # another attributes can be invalid and we are not testing them now

    fail_msg ||= "Expected #{attr} '#{value}'" +
                 " to be valid on #{described.name}.\n" +
                 "Errors on #{attr}: <#{subject.errors.inspect}>"

    assert_empty subject.errors[attr], fail_msg
  end

  def assert_order_ascending(collection, msg = nil)
    msg ||= "<#{collection.inspect}> expected to be on ascending order"

    ordered = collection.each_cons(2).all? do |expected_lesser, expected_greater|
      expected_lesser <= expected_greater
    end

    assert ordered, msg
  end

  def assert_order_descending(collection, msg = nil)
    msg ||= "<#{collection.inspect}> expected to be on descending order"

    ordered = collection.each_cons(2).all? do |expected_lesser, expected_greater|
      expected_lesser >= expected_greater
    end

    assert ordered, msg
  end

  module Base
    def described(described = nil)
      return @described = described if described

      @described ||= self.name.gsub(/Test$/, '')
        .split('::')
        .reduce(Object) do |parent, local_name|
        parent.const_get(local_name)
      end
    rescue
      raise "Impossible to determine described target for" +
        " #{self.name}\nPlease overwrite #described" +
        " returning the described class."
    end
  end
end
