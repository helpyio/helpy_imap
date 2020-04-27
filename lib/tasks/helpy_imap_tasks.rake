namespace :helpy do

  desc "Get email from IMAP/POP3 once"
  task :fetch_mail => :environment do
    ImapProcessor.fetch
  end

end
