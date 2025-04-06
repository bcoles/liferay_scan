#
# This file is part of LiferayScan
# https://github.com/bcoles/liferay_scan
#

require 'uri'
require 'cgi'
require 'logger'
require 'net/http'
require 'openssl'
require 'stringio'

class LiferayScan
  VERSION = '0.0.2'.freeze
  @resource_path = File.join(File.dirname(File.expand_path(__FILE__)), '../data')

  class << self
    attr_reader :logger
  end

  class << self
    attr_writer :logger
  end

  def self.insecure
    @insecure ||= false
  end

  class << self
    attr_writer :insecure
  end

  #
  # Check if URL is running Liferay
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.detectLiferay(url)
    return true if detectLiferayFromLogin(url)
    return true if detectLiferayFromHome(url)

    false
  end

  #
  # Check if URL is running Liferay using login page
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.detectLiferayFromLogin(url)
    url += '/' unless url.to_s.end_with?('/')

    res = sendHttpRequest("#{url}c/portal/login")

    return false unless res
    return false unless res.code.to_i == 302

    return true if res['liferay-portal'].to_s.start_with?('Liferay')

    # old Liferay <= 6.x
    return true if res['location'] =~ /p_p_id=58/

    # new Liferay >= 7.x
    return true if res['location'] =~ /p_p_id=com_liferay_login_web_portlet_LoginPortlet/

    false
  end

  #
  # Check if URL is running Liferay using home page
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.detectLiferayFromHome(url)
    url += '/' unless url.to_s.end_with?('/')

    res = sendHttpRequest("#{url}home")

    return false unless res
    return false unless res.code.to_i == 200

    return true if res['liferay-portal'].to_s.start_with?('Liferay')
    return true if res.body.to_s.include?('var Liferay = Liferay || {};')
    return true if res.body.to_s.include?('var Liferay = {')

    false
  end

  # Get Liferay version
  #
  # @param [String] URL
  #
  # @return [String] Liferay version
  #
  def self.getVersion(url)
    version = getVersionFromLogin(url)
    return version if version

    version = getVersionFromGuestHome(url)
    return version if version

    nil
  end

  #
  # Get Liferay version from login page
  #
  # @param [String] URL
  #
  # @return [String] Liferay version
  #
  def self.getVersionFromLogin(url)
    url += '/' unless url.to_s.end_with?('/')

    res = sendHttpRequest("#{url}")

    return unless res

    if res['liferay-portal'].to_s.start_with?('Liferay') && res['liferay-portal'].to_s.include?('.')
      return res['liferay-portal'].to_s
    end

    res.body.to_s.scan(/<div class="clearfix component-paragraph text-break" data-lfr-editable-id="element-text" data-lfr-editable-type="rich-text">\s*(Welcome to )?(Liferay [^<]+)\s*</).flatten[1]
  end

  #
  # Get Liferay version from guest home page
  #
  # @param [String] URL
  #
  # @return [String] Liferay version
  #
  def self.getVersionFromGuestHome(url)
    url += '/' unless url.to_s.end_with?('/')

    res = sendHttpRequest("#{url}web/guest/home")

    return unless res

    if res['liferay-portal'].to_s.start_with?('Liferay') && res['liferay-portal'].to_s.include?('.')
      return res['liferay-portal'].to_s
    end

    # Hello World default post
    res.body.to_s.scan(%r{<div class="portlet-body">\s*Welcome to (Liferay Portal [^<]+)\.\s*</div>}).flatten.first
  end

  # Get server from server error page
  #
  # @param [String] URL
  #
  # @return [String] Server version
  #
  def self.getServerVersion(url)
    url += '/' unless url.to_s.end_with?('/')

    res = sendHttpRequest("#{url}api/liferay")

    return unless res

    tomcat = res.body.scan(%r{>(Apache Tomcat/[0-9.]+)}).flatten.first
    return tomcat if tomcat

    glassfish = res.body.scan(/>(GlassFish Server Open Source Edition [0-9.]+)/).flatten.first
    return glassfish if glassfish

    nil
  end

  # Get client IP address from server error page
  # This may disclose the IP address of intermediary proxy servers
  #
  # @param [String] URL
  #
  # @return [String] Client IP address
  #
  def self.getClientIpAddress(url)
    url += '/' unless url.to_s.end_with?('/')

    res = sendHttpRequest("#{url}api/liferay")

    return unless res

    res.body.scan(/>Access denied for ([\d.]+)</).flatten.first
  end

  #
  # Get Liferay default language
  #
  # @param [String] URL
  #
  # @return [String] Liferay language
  #
  def self.getLanguage(url)
    url += '/' unless url.to_s.end_with?('/')

    res = sendHttpRequest(url)

    return unless res

    res['set-cookie'].to_s.scan(/GUEST_LANGUAGE_ID=([a-z]{2,3}_[A-Z]{2,3})/).flatten.first
  end

  #
  # Retrieve organisation email address domain
  #
  # @param [String] URL
  #
  # @return [String] Organisation email address domain
  #
  def self.getOrganisationEmail(url)
    url += '/' unless url.to_s.end_with?('/')

    # old Liferay <= 6.x
    res = sendHttpRequest("#{url}web/guest/home?p_p_id=58&p_p_lifecycle=0&p_p_state=maximized&p_p_mode=view&saveLastPath=false")
    if res && res.body =~ (/name="_58_login"[^>]+type="text"\s*value="&#x40;([^"]+)"/)
      return CGI.unescapeHTML(::Regexp.last_match(1))
    end

    # new Liferay >= 7.x
    res = sendHttpRequest("#{url}home?p_p_id=com_liferay_login_web_portlet_LoginPortlet&p_p_lifecycle=0&p_p_state=maximized&p_p_mode=view&saveLastPath=false")
    if res
      return res.body.scan(/name="_com_liferay_login_web_portlet_LoginPortlet_login"\s*type="text"\s*value="@([^"]+)"/).flatten.first
    end

    nil
  end

  #
  # Retrieve names from open search
  #
  # @param [String] URL
  #
  # @return [Array] list of users
  #
  def self.getUsersFromSearch(url)
    url += '/' unless url.to_s.end_with?('/')

    res = sendHttpRequest("#{url}c/search/open_search")

    return [] unless res
    return [] unless res.body

    valid_users = []
    res.body.encode('UTF-8', invalid: :replace, undef: :replace).scan(/\[Users &raquo; ([^\]]+)\]/).each do |full_name|
      next if full_name.empty?

      valid_users << [nil, full_name.flatten.first]
    end

    valid_users
  rescue StandardError
    @logger.error("#{e.message}")
    []
  end

  #
  # Check if account registration is enabled
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.userRegistration(url)
    url += '/' unless url.to_s.end_with?('/')

    # new Liferay >= 7.x
    res = sendHttpRequest("#{url}web/guest/home?p_p_id=com_liferay_login_web_portlet_LoginPortlet&p_p_lifecycle=0&p_p_state=maximized&p_p_mode=view&_com_liferay_login_web_portlet_LoginPortlet_mvcRenderCommandName=%2Flogin%2Fcreate_account&saveLastPath=false")
    if res && res.body.include?('_com_liferay_login_web_portlet_LoginPortlet_firstName') && res.body.include?('_com_liferay_login_web_portlet_LoginPortlet_lastName')
      return true
    end

    # old Liferay <= 6.x
    res = sendHttpRequest("#{url}web/guest/home?p_p_id=58&p_p_lifecycle=0&p_p_state=maximized&p_p_mode=view&saveLastPath=false&_58_struts_action=%2Flogin%2Fcreate_account")
    return true if res && res.body =~ /_58_firstName/ && res.body =~ /_58_lastName/

    false
  end

  #
  # Check if Single SignOn (SSO) authentication is enabled
  #
  # @param [String] URL
  #
  # @return [Boolean] SSO authentication is enabled
  #
  def self.ssoAuthEnabled(url)
    url += '/' unless url.to_s.end_with?('/')

    res = sendHttpRequest("#{url}c/portal/login")

    return false unless res

    return true if res.body.to_s.include?('name="SAMLRequest"')
    return true if res.body =~ /id="idpEntityId"\s+name="idpEntityId"/

    false
  end

  #
  # Check if remote access to the SOAP API is allowed
  # https://help.liferay.com/hc/en-us/articles/360018161151-SOAP-Web-Services
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.remoteSoapApi(url)
    url += '/' unless url.to_s.end_with?('/')

    res = sendHttpRequest("#{url}api/axis")

    return false unless res
    return false unless res.code.to_i == 200

    return true if res.body.to_s.include?('<h2>And now... Some Services</h2>')

    false
  end

  #
  # Check if remote access to the JSON API is allowed
  # https://liferay.atlassian.net/browse/LPSA-86672
  # https://help.liferay.com/hc/en-us/articles/360018179011-Portal-Configuration-of-JSON-Web-Services
  # https://help.liferay.com/hc/en-us/articles/360017882172-Configuring-JSON-Web-Services-#controlling-public-access
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.remoteJsonApi(url)
    url += '/' unless url.to_s.end_with?('/')

    res = sendHttpRequest("#{url}api/jsonws")

    return false unless res
    return false unless res.code.to_i == 200

    return true if res.body.to_s.include?('<title>json-web-services-api</title>')
    return true if res.body.to_s.include?('"JSONWS API"')

    false
  end

  #
  # Check if Forgot Password is enabled
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.passwordResetEnabled(url)
    url += '/' unless url.to_s.end_with?('/')

    # new Liferay >= 7.x
    res = sendHttpRequest("#{url}home?p_p_id=com_liferay_login_web_portlet_LoginPortlet&p_p_lifecycle=0&p_p_state=maximized&p_p_mode=view&_com_liferay_login_web_portlet_LoginPortlet_mvcRenderCommandName=%2Flogin%2Fforgot_password&saveLastPath=false")
    return true if res && res.body.to_s.include?('Forgot Password')

    # old Liferay <= 6.x
    res = sendHttpRequest("#{url}web/guest/home?p_p_id=58&p_p_lifecycle=0&p_p_state=exclusive&p_p_mode=view&_58_struts_action=%2Flogin%2Fforgot_password")
    return true if res && res.body.to_s.include?('Forgot Password')

    false
  end

  #
  # Check if Forgot Password requires CAPTCHA
  #
  # @param [String] URL
  #
  # @return [Boolean]
  #
  def self.passwordResetUsesCaptcha(url)
    url += '/' unless url.to_s.end_with?('/')

    # new Liferay >= 7.x
    res = sendHttpRequest("#{url}home?p_p_id=com_liferay_login_web_portlet_LoginPortlet&p_p_lifecycle=0&p_p_state=maximized&p_p_mode=view&_com_liferay_login_web_portlet_LoginPortlet_mvcRenderCommandName=%2Flogin%2Fforgot_password&saveLastPath=false")
    if res
      return true if res.body.to_s.include?('id="_58_captcha"')
      return true if res.body.to_s.include?('id="_com_liferay_login_web_portlet_LoginPortlet_captchaText"')
      return true if res.body.to_s.include?('RecaptchaOptions')
    end

    # old Liferay <= 6.x
    res = sendHttpRequest("#{url}web/guest/home?p_p_id=58&p_p_lifecycle=0&p_p_state=exclusive&p_p_mode=view&_58_struts_action=%2Flogin%2Fforgot_password")
    if res
      return true if res.body.to_s.include?('id="_58_captcha"')
      return true if res.body.to_s.include?('id="_com_liferay_login_web_portlet_LoginPortlet_captchaText"')
      return true if res.body.to_s.include?('RecaptchaOptions')
    end

    false
  end

  #
  # Enumerate users
  #
  # @param [String] URL
  #
  # @return [Array] list of users
  #
  def self.enumerateUsersFromBlogRss(url)
    url += '/' unless url.to_s.end_with?('/')

    # load potential usernames from gem data files
    users = File.readlines("#{@resource_path}/users.txt")
    users.concat(File.readlines("#{@resource_path}/names.txt"))

    # enumerate common user names from blog RSS feed
    valid_users = []
    users.sort.uniq.each do |screen_name|
      next if screen_name.start_with?('#')

      screen_name.chomp!

      next if screen_name.empty?

      res = sendHttpRequest("#{url}web/#{URI::Parser.new.escape(screen_name)}/home/-/blogs/rss")

      next if res.nil?
      next if res.code.to_i != 200

      full_name = res.body.to_s.scan(%r{<subtitle>(.+?)</subtitle>}).flatten.first

      next unless full_name

      valid_users << [screen_name, full_name]
    end

    valid_users
  rescue StandardError => e
    @logger.error("#{e.message}")
    []
  end

  #
  # Fetch URL
  #
  # @param [String] URL
  #
  # @return [Net::HTTPResponse] HTTP response
  #
  def self.sendHttpRequest(url)
    target = URI.parse(url)
    @logger.info("Fetching #{target}")

    http = Net::HTTP.new(target.host, target.port)
    if target.scheme.to_s.eql?('https')
      http.use_ssl = true
      http.verify_mode = @insecure ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
    end
    http.open_timeout = 20
    http.read_timeout = 20
    headers = {}
    headers['User-Agent'] = "LiferayScan/#{VERSION}"
    headers['Accept-Encoding'] = 'gzip,deflate'

    begin
      res = http.request(Net::HTTP::Get.new(target, headers.to_hash))
    rescue Timeout::Error, Errno::ETIMEDOUT
      @logger.error("Could not retrieve URL #{target}: Timeout")
      return nil
    rescue StandardError => e
      @logger.error("Could not retrieve URL #{target}: #{e}")
      return nil
    end

    @logger.info("Received reply (#{res.body.length} bytes)")

    begin
      if res.body && res['Content-Encoding'].eql?('gzip')
        sio = StringIO.new(res.body)
        gz = Zlib::GzipReader.new(sio)
        res.body = gz.read
      end
    rescue Zlib::GzipFile::Error => e
      # Not compressed? Return raw response.
      @logger.info("Gzip decompression failed: #{e.message}")
    end

    res
  end
end
