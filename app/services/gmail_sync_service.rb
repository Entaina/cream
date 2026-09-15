class GmailSyncService
  DEFAULT_LOOKBACK = 14.days

  def initialize(connection:, reader: nil)
    @connection = connection
    @reader = reader || GmailReader.new(connection)
  end

  def sync!
    return false unless @connection.sync_enabled? && @connection.connected? && @connection.can_read_metadata?

    after = sync_after
    known_by_thread = known_outbound.index_by(&:gmail_thread_id)
    known_by_message_id = known_outbound.index_by { |message| normalize_message_id(message.rfc822_message_id) }
    processed_ids = {}

    known_by_thread.keys.compact.uniq.each do |thread_id|
      @reader.get_thread_metadata(thread_id).each do |metadata|
        process_inbound!(metadata, after:, known_by_thread:, known_by_message_id:, processed_ids:)
      end
    end

    if known_outbound.where(replied_at: nil).exists?
      scan_inbox_for_replies(after:, known_by_thread:, known_by_message_id:, processed_ids:)
    end

    @connection.update!(last_synced_at: Time.current)
    true
  rescue GmailReader::Error => e
    Rails.logger.error("Gmail sync failed for GmailConnection##{@connection.id}: #{e.message}")
    false
  end

  private

  def sync_after
    after = @connection.last_synced_at || DEFAULT_LOOKBACK.ago
    pending = known_outbound.where(replied_at: nil)
    return after unless pending.exists?

    oldest_pending = pending.minimum(:created_at)
    [after, oldest_pending - 1.hour].min
  end

  def known_outbound
    @connection.workspace.email_messages
      .outbound
      .where(user_id: @connection.user_id)
      .where.not(gmail_thread_id: nil)
      .where(status: %w[sent opened])
  end

  def scan_inbox_for_replies(after:, known_by_thread:, known_by_message_id:, processed_ids:)
    @reader.list_recent_message_ids(after: after).each do |message_id|
      next if processed_ids[message_id]

      metadata = @reader.get_metadata(message_id)
      process_inbound!(metadata, after:, known_by_thread:, known_by_message_id:, processed_ids:)
    end
  end

  def process_inbound!(metadata, after:, known_by_thread:, known_by_message_id:, processed_ids:)
    return if processed_ids[metadata.id]
    return if after.present? && metadata.internal_date.positive? && metadata.internal_date < after.to_i * 1000

    processed_ids[metadata.id] = true
    return if sent_by_us?(metadata)

    outbound = match_outbound(metadata, known_by_thread, known_by_message_id)
    return unless outbound

    mark_replied!(outbound, metadata) unless outbound.replied?
    capture_inbound!(outbound, metadata.id) if @connection.can_read_body?
  end

  def sent_by_us?(metadata)
    metadata.label_ids.include?("SENT") || from_address(metadata.from) == from_address(@connection.email)
  end

  def match_outbound(metadata, known_by_thread, known_by_message_id)
    by_thread = known_by_thread[metadata.thread_id]
    return by_thread if by_thread

    referenced_ids(metadata).each do |reference|
      match = known_by_message_id[reference]
      return match if match
    end

    nil
  end

  def referenced_ids(metadata)
    text = [metadata.references, metadata.in_reply_to].compact.join(" ")
    text.scan(/<[^>]+>/).map { |token| normalize_message_id(token) }
  end

  def normalize_message_id(value)
    value.to_s.strip.downcase
  end

  def from_address(raw)
    match = raw.to_s.match(/<([^>]+)>/)
    (match ? match[1] : raw).to_s.strip.downcase
  end

  def mark_replied!(outbound, metadata)
    outbound.update!(replied_at: Time.current)
    record = outbound.record
    if record.respond_to?(:track_activity)
      record.track_activity(
        "email_replied",
        user: outbound.user,
        metadata: {subject: outbound.subject, from: metadata.from}.compact
      )
    end
    NotificationService.notify_email_replied(message: outbound) if CreamFeatures.enabled?(:notifications)
  end

  def capture_inbound!(outbound, gmail_message_id)
    return if @connection.workspace.email_messages.exists?(gmail_message_id: gmail_message_id)
    return if @connection.full_read_blocked_by_metadata?

    full = @reader.get_full(gmail_message_id)
    body = full.body_text.presence || full.snippet.presence || "(no content)"

    @connection.workspace.email_messages.create!(
      direction: "inbound",
      status: "received",
      user: outbound.user,
      record: outbound.record,
      in_reply_to: outbound,
      from_address: full.from,
      to_address: @connection.email,
      subject: full.subject.presence || "Re: #{outbound.subject}",
      body: body,
      gmail_message_id: full.id,
      gmail_thread_id: full.thread_id,
      rfc822_message_id: full.message_id
    )
  rescue GmailReader::Error => e
    Rails.logger.warn("Gmail inbound capture failed for #{gmail_message_id}: #{e.message}")
  end
end
