# Combines the content and audit history without repeating note/email creation events.
# Each source only loads the prefix needed for the requested page.
class RecordActivityFeed
  PAGE_SIZE = 30
  FILTERS = %w[all notes emails comments changes].freeze

  attr_reader :filter, :page, :pages

  def initialize(record, filter: nil, page: nil, emails: true, comments: true)
    @filter = filter.presence_in(FILTERS) || "all"
    @scopes = []
    @scopes << record.notes.includes(:user) if %w[all notes].include?(@filter)
    @scopes << record.email_messages.includes(:user, attachments_attachments: :blob) if emails && %w[all emails].include?(@filter)
    @scopes << record.comments.top_level.includes(:user) if comments && %w[all comments].include?(@filter)

    if %w[all changes emails].include?(@filter)
      activities = record.activities.includes(:user, :subject).where.not(action: %w[note_added comment_added])
      activities = emails ? activities.where.not(action: "email_sent") : activities.where("action NOT LIKE 'email_%'")
      activities = activities.where("action LIKE 'email_%'") if @filter == "emails"
      activities = activities.where("action NOT LIKE 'email_%'") if @filter == "changes"
      @scopes << activities
    end

    @pages = [(@scopes.sum(&:count).to_f / PAGE_SIZE).ceil, 1].max
    @page = page.to_i.clamp(1, @pages)
  end

  def entries
    @entries ||= @scopes.flat_map { |scope| scope.reorder(created_at: :desc, id: :desc).limit(page * PAGE_SIZE).to_a }
      .sort_by { |entry| [entry.created_at, entry.class.name, entry.id] }.reverse
      .slice((page - 1) * PAGE_SIZE, PAGE_SIZE) || []
  end
end
