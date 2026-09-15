class EmailPreviewRecord
  CompanyStub = Struct.new(:name)

  def initialize(tokens = {})
    @tokens = tokens.stringify_keys
  end

  def first_name = @tokens["first_name"]
  def last_name = @tokens["last_name"]
  def display_name = @tokens["name"]
  def name = @tokens["name"]
  def email = @tokens["email"]

  def company
    @company ||= CompanyStub.new(@tokens["company"])
  end
end
