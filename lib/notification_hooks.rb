class NotificationHook < Redmine::Hook::Listener

  def controller_issues_new_after_save(context={})
    issue = context[:issue]
    @settings = get_settings(issue)
    return true unless @settings
    project = issue.project
    author  = CGI::escapeHTML(User.current.name)
    tracker = CGI::escapeHTML(issue.tracker.name.downcase)
    subject = CGI::escapeHTML(issue.subject)
    url     = get_url issue
    text    = "#{author} reported #{project.name} #{tracker} <a href=\"#{url}\">##{issue.id}</a>: #{subject}"

    send_message text
  end

  def controller_issues_edit_after_save(context={})
    issue = context[:issue]
    @settings = get_settings(issue)
    return true unless @settings
    project = issue.project
    author  = CGI::escapeHTML(User.current.name)
    tracker = CGI::escapeHTML(issue.tracker.name.downcase)
    subject = CGI::escapeHTML(issue.subject)
    comment = CGI::escapeHTML(context[:journal].notes)
    url     = get_url issue
    text    = "#{author} updated #{project.name} #{tracker} <a href=\"#{url}\">##{issue.id}</a>: #{subject}"
    text   += ": <i>#{truncate(comment)}</i>" unless comment.blank?

    send_message text
  end

private

  def get_url(object)
    case object
      when Issue then "#{Setting[:protocol]}://#{Setting[:host_name]}/issues/#{object.id}"
    else
      RAILS_DEFAULT_LOGGER.info "Asked redmine_hipchat for the url of an unsupported object #{object.inspect}"
    end
  end

  def send_message(message)
    if @settings[:auth_token].nil? || @settings[:room_id].nil? || @settings[:auth_token].blank? || @settings[:room_id].blank?
      RAILS_DEFAULT_LOGGER.info "Not sending HipChat message - missing config"
      return
    end

    RAILS_DEFAULT_LOGGER.info "Sending message to HipChat: #{message}"
    req = Net::HTTP::Post.new("/v1/rooms/message")
    req.set_form_data({
      :auth_token => @settings[:auth_token],
      :room_id => @settings[:room_id],
      :notify => @settings[:notify] ? 1 : 0,
      :from => 'Redmine',
      :message => message
    })
    req["Content-Type"] = 'application/x-www-form-urlencoded'

    http = Net::HTTP.new("api.hipchat.com", 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    begin
      http.start do |connection|
        connection.request(req)
      end
    rescue Net::HTTPBadResponse => e
      RAILS_DEFAULT_LOGGER.error "Error hitting HipChat API: #{e}"
    end
  end

  def get_settings(issue)
    Setting.find_by_name('plugin_redmine_hipchat_per_project').value[issue.project_id] rescue nil
  end

  def truncate(text, length = 20, end_string = '...')
    return unless text
    words = text.split()
    words[0..(length-1)].join(' ') + (words.length > length ? end_string : '')
  end

end