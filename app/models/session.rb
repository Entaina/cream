class Session < ApplicationRecord
  belongs_to :user
  has_many :list_filter_states, dependent: :delete_all
end
