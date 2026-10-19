class BookingPageCoHostNotifier
  def self.call(booking_page:, user_ids:, actor:)
    new(booking_page:, user_ids:, actor:).call
  end

  def initialize(booking_page:, user_ids:, actor:)
    @booking_page = booking_page
    @user_ids = Array(user_ids).map(&:to_i) - [actor.id]
    @actor = actor
  end

  def call
    @booking_page.workspace.users.where(id: @user_ids).find_each do |recipient|
      AlertChannelDelivery.for(user: recipient, workspace: @booking_page.workspace).deliver do |channels|
        NotificationService.notify_booking_page_invite(recipient:, booking_page: @booking_page, actor: @actor) if channels.in_app?
        BookingMailer.co_host_invitation(booking_page: @booking_page, recipient:, actor: @actor).deliver_later if channels.email?
      end
    end
  end
end
