class FetchMailJob < ApplicationJob
  queue_as :default

  def perform(message)
    # Process a new message and convert to ticket
    ImapProcessor.new(message).process
  end
end
