module GeekTestMacros
  module Models
    def should_count(n)
      test "counting #{described.name.pluralize}" do
        assert_equal n, described.count
      end
    end

    def should_find_all_records
      test "finding all #{described.name.pluralize}" do
        recs = described.all

        assert_equal described.count, recs.size
        assert(recs.all?{|rec| rec.is_a? described },
               "All registers expected to be" +
               " #{described.name.pluralize} but was" +
               " <#{recs.inspect}>")
      end
    end

    def should_find_single_record(record)
      test "finding a single #{described.name}" do
        record = find_fixture_for record if
          record.is_a? Symbol
        finded = described.find(record.id)

        assert_kind_of(described, finded)
        assert_equal record, finded
      end
    end

    def should_create(params = {})
      params = params[:with] or params
      test "persistence of a single #{described.name}" do
        assert_difference "#{described.name}.count" do
          @obj = described.create params
        end

        criteria = params.keys.first
        assert_equal(@obj, described
                       .where(criteria => params[criteria])
                       .first)
      end
    end

    def should_update(record, params = {})
      params = params[:with] or params

      test "update of #{described.name}'s attributes"  do
        record = find_fixture_for record if
          record.is_a? Symbol

        assert_no_difference "#{described.name}.count" do
          record.update_attributes params
        end

        criteria = params.keys.first
        assert_equal(record, described
                       .where(criteria => params[criteria])
                       .first)
      end
    end

    def should_destroy(record)
      test "deletion of a single #{described.name}" do
        record = find_fixture_for record if
          record.is_a? Symbol

        original_id = record.id
        assert_difference "#{described.name}.count", -1 do
          record.destroy
        end

        assert_raises ActiveRecord::RecordNotFound do
          described.find original_id
        end
      end
    end

    def should_validates_presence_of(*attrs)
      attrs.each do |attr|
        test "presence validation of #{attr}" do
          assert_no_difference "#{described.name}.count" do
            @obj = assert_bad_value(attr, '  ', :blank)
            @obj.save
          end
        end
      end
    end

    def should_validates_uniqueness_of(*attrs)
      attrs.each do |attr|
        test "uniqueness validation of #{attr}" do
          col    = described.arel_table[attr.to_sym]
          record = described.where(col.not_eq(nil)).first

          raise "To be able to test uniqueness of"  +
            " #{described.name}##{attr} you should have at least" +
            " one register with not null #{attr}" unless record

          assert_no_difference "#{described.name}.count" do
            orig_value = record.read_attribute(attr)
            @obj = assert_bad_value attr, orig_value, :taken
            @obj.save
          end
        end
      end
    end
  end
end
