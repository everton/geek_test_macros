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

  def error_message_for(kind)
    I18n.t("errors.messages")[kind.to_sym] ||
      I18n.t("activerecord.errors.messages")[kind.to_sym]
  end

  def assert_bad_value(attr, value, msg)
    msg = error_message_for(msg) if msg.is_a? Symbol
    error_msg = "#{described.name} with #{attr} '#{value}'" +
      " expected to not be valid"

    described.new(attr => value).tap do |new|
      refute new.valid?, error_msg

      assert_includes new.errors[attr], msg
    end
  end

  def assert_good_value(attr, value)
    described.new(attr => value) do |new|
      new.valid?
      assert_empty(new.errors[attr],
                   "Expected #{attr} '#{value}'" +
                   " to be valid on #{described.name}." +
                   "\nErrors on #{attr}: #{new.errors}")
    end
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
