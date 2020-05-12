class ImapProcessor

  def self.fetch
    begin
      Mail.defaults do
        if AppSettings["email.mail_service"] == 'pop3'
          retriever_method(
            :pop3, 
            address:    AppSettings['email.pop3_server'],
            port:       AppSettings['email.pop3_port'],
            user_name:  AppSettings['email.pop3_username'],
            password:   AppSettings['email.pop3_password'],
            enable_ssl: AppSettings['email.pop3_security'] == 'ssl' ? true : false
          )
        else
          retriever_method(
            :imap, 
            :address    => AppSettings['email.imap_server'],
            :port       => AppSettings['email.imap_port'],
            :user_name  => AppSettings['email.imap_username'],
            :password   => AppSettings['email.imap_password'],
            :enable_ssl => true
          )
        end
      end     

    rescue => e
      logger.error e
    end
    
    # get unread messages
    messages = Mail.find(keys: ['NOT', 'SEEN'], read_only: true)
    puts "found #{messages.count} messages"
    messages.each do |message|
      puts "processing email: #{message.subject}"
      # FetchMailJob.perform_later(message)
      ImapProcessor.new(message).process
    end

  end

  def initialize(email)
    @email = email
    @spam_score = 0
  end

  def process
    # Guard clause to prevent ESPs like Sendgrid from posting over and over again
    # if the email presented is invalid and generates a 500.  Returns a 200
    # error as discussed on https://sendgrid.com/docs/API_Reference/Webhooks/parse.html
    # This error happened with invalid email addresses from PureChat
    return if @email[:from].addresses.first.match(/\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/).blank?

    # Here we use a global spam score to system block spam, as well as a configurable
    # spam score to set status to SPAM above the configured level.

    # Outright reject spam from creating a ticket at all
    return if (@spam_score > AppSettings["email.spam_assassin_reject"].to_f)

    # Set attributes from email
    sitename = AppSettings["settings.site_name"]
    email_address = @email[:from].addresses.first.downcase
    email_name = @email[:from].display_names.first.blank? ? @email.from[:token].gsub(/[^a-zA-Z]/, '') : @email[:from].display_names.first
    # message = @email.body.nil? ? "" : encode_entity(@email.body)
    # raw = @email.raw_body.nil? ? "" : encode_entity(@email.raw_body)
    binding.pry
    message =  @email.text_part.present? ? @email.text_part.decoded : encode_entity(@email.body.raw_source)
    raw = message
    to = @email.to.first
    cc = @email.cc ? @email.cc.map { |e| e[:full] }.join(", ") : nil
    token = email_address.split('@')[0]
    subject = check_subject(@email.subject)
    attachments = @email.attachments
    number_of_attachments = attachments.present? ? attachments.size : 0
    spam_report = ''

    if subject.include?("[#{sitename}]") # this is a reply to an existing topic
      ImapProcessor.create_reply_from_email(@email, email_address, email_name, subject, raw, message, token, to, sitename, cc, number_of_attachments, @spam_score, spam_report)
    elsif subject.include?("Fwd: ") # this is a forwarded message TODO: Expand this to handle foreign email formatting
      ImapProcessor.create_forwarded_message_from_email(@email, subject, raw, message, token, to, cc, number_of_attachments, @spam_score, spam_report)
    else # this is a new direct message
      ImapProcessor.create_new_ticket_from_email(@email, email_address, email_name, subject, raw, message, token, to, cc, number_of_attachments, @spam_score, spam_report)
    end
  rescue => e
      puts e
  end

  # Creates a new ticket from an email
  def self.create_new_ticket_from_email(email, email_address, email_name, subject, raw, message, token, to, cc, number_of_attachments, spam_score, spam_report)

    # flag as spam if below spam score threshold
    ticket_status = (spam_score > AppSettings["email.spam_assassin_filter"].to_f) ? "spam" : "new"

    @user = User.where("lower(email) = ?", email_address).first
    if @user.nil?
      @user = EmailProcessor.create_user_for_email(email_address, token, email_name, ticket_status)
    end

    topic = Forum.first.topics.new(
      name: subject, 
      user_id: @user.id,
      private: true,
      current_status: ticket_status,
      spam_score: spam_score,
      spam_report: spam_report
    )

    if topic.save
      if token.include?("+")
        topic.team_list.add(token.split('+')[1])
        topic.save
        topic.team_list.add(token)
        topic.save
      end
      #insert post to new topic
      message = "-" if message.blank? && number_of_attachments > 0
      post = topic.posts.create(
        body: message,
        raw_email: raw,
        user_id: @user.id,
        kind: "first",
        cc: cc,
        email_to_address: to
      )
      # Push array of attachments and send to Cloudinary
      ImapProcessor.handle_attachments(email, post)


    end
  end

    # Creates a ticket from a forwarded email
  def self.create_forwarded_message_from_email(email, subject, raw, message, token, to, cc, number_of_attachments, spam_score, spam_report)

    # Parse from out of the forwarded raw body
    from = raw[/From: .*<(.*?)>/, 1]
    from_token = from.split("@")[0]

    # flag as spam if below spam score threshold
    ticket_status = (spam_score > AppSettings["email.spam_assassin_filter"].to_f) ? "spam" : "new"

    # scan users DB for sender email
    @user = User.where("lower(email) = ?", from).first
    if @user.nil?
      @user = EmailProcessor.create_user_for_email(from, from_token, "", ticket_status)
    end

    #clean message
    message = MailExtract.new(raw).body

    topic = Forum.first.topics.new(
      name: subject,
      user_id: @user.id,
      private: true,
      current_status: ticket_status,
      spam_score: spam_score,
      spam_report: spam_report
    )

    if topic.save
      #insert post to new topic
      message = "-" if message.blank? && number_of_attachments > 0
      post = topic.posts.create!(
        body: raw,
        raw_email: raw,
        user_id: @user.id,
        kind: 'first',
        cc: cc,
        email_to_address: to
      )

      # Push array of attachments and send to Cloudinary
      ImapProcessor.handle_attachments(email, post)
    end
  end

  # Adds a reply to an existing ticket thread from an email response.
  def self.create_reply_from_email(email, email_address, email_name, subject, raw, message, token, to, sitename, cc, number_of_attachments, spam_score, spam_report)      
    
    # flag as spam if below spam score threshold
    ticket_status = (spam_score > AppSettings["email.spam_assassin_filter"].to_f) ? "spam" : "new"
        
    @user = User.where("lower(email) = ?", email_address).first
    if @user.nil?
      @user = EmailProcessor.create_user_for_email(email_address, token, email_name, ticket_status)
    end

    complete_subject = subject.split("[#{sitename}]")[1].strip
    ticket_number = complete_subject.split("-")[0].split("#")[1].strip
    topic = Topic.find(ticket_number)

    if topic.present?
      # insert post to new topic
      message = "-" if message.blank? && number_of_attachments > 0
      post = topic.posts.create(
        body: message,
        raw_email: raw,
        user_id: @user.id,
        kind: "reply",
        cc: cc,
        email_to_address: to
      )

      # Push array of attachments and send to Cloudinary
      ImapProcessor.handle_attachments(email, post)
    end
  end


  # Insert a default subject if subject is missing
  def check_subject(subject)
    subject.blank? ? "(No Subject)" : subject
  end

  def encode_entity(entity)
    !entity.nil? ? entity.encode('utf-8', invalid: :replace, replace: '?') : entity
  end

  def self.handle_attachments(email, post)
    return unless email.attachments.present?
    
    if AppSettings['cloudinary.cloud_name'].present? && AppSettings['cloudinary.api_key'].present? && AppSettings['cloudinary.api_secret'].present?
      array_of_files = []
      email.attachments.each do |attachment|
        array_of_files << File.open(attachment.tempfile.path, 'r')
      end
      post.screenshots = array_of_files
    else
      all_attachments = []
      email.attachments.each do |attachment|
        filename = attachment.filename
        extension = File.extname(filename)
        # Produce a nice tmpfile with human readable display name and preserve the extension 
        tempfile = Tempfile.new([File.basename(filename, extension) + '-', extension])
        # The `b` flag is important
        File.open(tempfile, 'wb') { |f| f.write(attachment.decoded) }
        
        # Assemble an array that contains each attachment
        all_attachments << Pathname.new(tempfile.path).open
      end
      # Save array
      post.attachments = all_attachments
      post.save if post.valid?

    end
  end

  def cloudinary_enabled?
    AppSettings['cloudinary.cloud_name'].present? && AppSettings['cloudinary.api_key'].present? && AppSettings['cloudinary.api_secret'].present?
  end

end