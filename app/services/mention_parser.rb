class MentionParser
  MENTION_PATTERN = /@([\w.-]+)/

  def self.users_from(text, workspace:)
    return [] if text.blank?

    handles = text.scan(MENTION_PATTERN).flatten.map(&:downcase).uniq
    return [] if handles.empty?

    handles.filter_map { |handle| user_for_handle(handle, workspace: workspace) }.uniq
  end

  def self.render_html(text, workspace:)
    AutoLinker.render_html(text) do |segment|
      segment.gsub(MENTION_PATTERN) do |match|
        handle = Regexp.last_match(1)
        user = user_for_handle(handle, workspace: workspace)
        if user
          %(<span class="text-accent font-medium">@#{CGI.escapeHTML(user.name)}</span>)
        else
          match
        end
      end
    end
  end

  def self.user_for_handle(handle, workspace:)
    handle = handle.downcase
    workspace.users.find do |user|
      user.email_address.downcase.start_with?("#{handle}@") ||
        user.name.downcase == handle ||
        user.name.downcase.include?(handle)
    end
  end
  private_class_method :user_for_handle
end
