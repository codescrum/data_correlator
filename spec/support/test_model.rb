class TestModel
  include Virtus.model

  # Base attributes
  attribute :id, Integer
  attribute :first_name, String
  attribute :last_name, String
  attribute :description, String
  attribute :email, String
  attribute :address, String
  attribute :email, String
  attribute :boolean, Boolean

  # return only the present attributes
  def present_attributes
    self.attributes.select{|k,v| v.present?}
  end

end
