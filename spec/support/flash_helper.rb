module FlashHelper
  def expect_notice(text)
    expect(response.body).to match(/#{Regexp.escape(text)}/i)
  end
end

RSpec.configure do |config|
  config.include FlashHelper, type: :request
end
