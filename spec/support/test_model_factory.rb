# A simple factory is all we need
class TestModelFactory

  # @param how_many
  # @param options
  # options[:fields] => fields to automatically populate
  # default fields to populate: only `id`
  #
  def self.create_list(how_many, options = {})

    options ||= {}

    options[:fields] ||= TestModel.attribute_set.map{|attribute| attribute.name}
    options[:prefix] ||= 'test'
    fields = options[:fields]
    prefix = options[:prefix]

    # ------------------------
    test_models = []

    how_many.times do |i|
      test_model = TestModel.new
      test_model.id = i if fields.include? :id
      test_model.first_name = "#{prefix}_FN_#{i}" if fields.include? :first_name
      test_model.last_name = "#{prefix}_LN_#{i}" if fields.include? :last_name
      test_model.email = "#{prefix}_#{i}@test.com" if fields.include? :email
      test_model.description = "#{prefix}_description_#{i}" if fields.include? :description
      test_models << test_model
    end

    test_models
  end

end
