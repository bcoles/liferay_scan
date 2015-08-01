# This file is part of LiferayScan
# https://github.com/bcoles/LiferayScan

require 'uri'
require 'cgi'
require 'net/http'
require 'openssl'

class LiferayScan
  @version = '0.0.1'
  @resource_path = File.join(File.dirname(File.expand_path(__FILE__)), '../data')

  #
  # Check if Liferay
  #
  def self.isLiferay(url)
    url += '/' unless url.match /\/$/
    res = self.sendHttpRequest("#{url}c/portal/login")
    if res && res.code.to_i == 302 && res['location'] =~ /p_p_id=58/
      return true
    else
      return false
    end
  end

  #
  # Get Liferay version
  #
  def self.getVersion(url)
    url += '/' unless url.match /\/$/
    version = nil
    res = self.sendHttpRequest("#{url}web/guest/home")
    # Liferay-Portal HTTP header
    if res && res['liferay-portal'] =~ /\ALiferay/
      version = res['liferay-portal'].to_s
    # Hello World default post
    elsif res && res.body && res.body =~ /<div class="portlet-body">\s*Welcome to (Liferay Portal [^<]+)\.\s*<\/div>/
      version = $1
    end
    version
  end

  #
  # Get Liferay default language
  #
  def self.getLanguage(url)
    url += '/' unless url.match /\/$/
    language = nil
    res = self.sendHttpRequest(url)
    if res && res['set-cookie'] =~ /GUEST_LANGUAGE_ID=([a-z]{2,3}_[A-Z]{2,3})/
      language = $1
    end
    language
  end

  #
  # Retrieve organisation email address domain
  #
  def self.getOrganisationEmail(url)
    url += '/' unless url.match /\/$/
    domain = nil
    res = self.sendHttpRequest("#{url}web/guest/home?p_p_id=58&p_p_lifecycle=0&p_p_state=maximized&p_p_mode=view&saveLastPath=false")
    if res && res.code && res.code.to_i == 200 && res.body =~ /name="_58_login"\s*type="text"\s*value="&#x40;([^"]+)"/
      domain = CGI.unescapeHTML($1)
    end
    domain
  end

  #
  # Check if account registration is enabled
  #
  def self.userRegistration(url)
    url += '/' unless url.match /\/$/
    res = self.sendHttpRequest("#{url}web/guest/home?p_p_id=58&p_p_lifecycle=0&p_p_state=maximized&p_p_mode=view&saveLastPath=false&_58_struts_action=%2Flogin%2Fcreate_account")
    if res && res.code && res.code.to_i == 200 && res.body =~ /_58_firstName/ && res.body =~ /_58_lastName/
      return true
    else
      return false
    end
  end

  #
  # Check if remote access to the SOAP API is allowed
  # http://www.liferay.com/documentation/liferay-portal/6.1/development/-/ai/invoking-the-api-remotely
  # https://www.liferay.com/documentation/liferay-portal/6.1/development/-/ai/soap-web-services
  #
  def self.remoteSoapApi(url)
    url += '/' unless url.match /\/$/
    res = self.sendHttpRequest("#{url}api/axis")
    if res && res.code && res.code.to_i == 200 && res.body =~ /<h2>And now\.\.\. Some Services<\/h2>/
      return true
    else
      return false
    end
  end

  #
  # Check if remote access to the JSON API is allowed
  # http://www.liferay.com/documentation/liferay-portal/6.1/development/-/ai/invoking-the-api-remotely
  # https://www.liferay.com/documentation/liferay-portal/6.1/development/-/ai/json-web-services
  #
  def self.remoteJsonApi(url)
    url += '/' unless url.match /\/$/
    res = self.sendHttpRequest("#{url}api/jsonws")
    if res && res.code && res.code.to_i == 200 && res.body =~ /<title>json-web-services-api<\/title>/
      return true
    else
      return false
    end
  end

  #
  # Enumerate users
  #
  def self.enumerateUsers(url)
    url += '/' unless url.match /\/$/
    valid_users = []
    # enumerate common user names from using blog RSS feed
    file = File.open("#{@resource_path}/users.txt", "r")
    users = file.read.split("\n")
    file.close
    users.each do |screen_name|
      res = self.sendHttpRequest("#{url}web/#{screen_name}/home/-/blogs/rss")
      next if res.nil?
      next if res.code.nil?
      if res.code.to_i == 200 && res.body =~ /<subtitle>(.+)<\/subtitle>/
        full_name = $1
        valid_users << [screen_name, full_name]
      else
      end
    end
    # enumerate common names using blog RSS feed
    file = File.open("#{@resource_path}/names.txt", "r")
    users = file.read.split("\n")
    file.close
    users.each do |screen_name|
      next if screen_name =~ /^#/ # skip comments
      res = self.sendHttpRequest("#{url}web/#{screen_name}/home/-/blogs/rss")
      next if res.nil?
      next if res.code.nil?
      if res.code.to_i == 200 && res.body =~ /<subtitle>(.+)<\/subtitle>/
        full_name = $1
        valid_users << [screen_name, full_name]
      else
      end
    end
    # retrieve names from open search
    res = self.sendHttpRequest("#{url}c/search/open_search")
    if res && res.body
      body = res.body.encode('UTF-8', invalid: :replace, undef: :replace)
      body.scan(/\[Users \&raquo; ([^\]]+)\]/).each do |full_name|
        valid_users << [nil, full_name.flatten.first]
      end
    end
    valid_users
  end

  #
  # Check if Forgot Password requires CAPTCHA
  #
  def self.usesCaptcha(url)
    url += '/' unless url.match /\/$/
    res = self.sendHttpRequest("#{url}web/guest/home?p_p_id=58&p_p_lifecycle=0&p_p_state=exclusive&p_p_mode=view&_58_struts_action=%2Flogin%2Fforgot_password")
    if res && res.code && res.code.to_i == 200 && res.body =~ /id="_58_emailAddress"/
      return true if res.body =~ /(id="_58_captcha"|RecaptchaOptions)/
    end
  end

  #
  # Enumerate portlets
  # https://www.liferay.com/community/wiki/-/wiki/Main/Liferay+portlets
  #
  def self.enumeratePortlets(url)
    url += '/' unless url.match /\/$/
    installed_portlets = []
    file = File.open("#{@resource_path}/portlets.txt", "r")
    portlets = file.read.split("\n")
    file.close
    portlets.each do |portlet|
      # load view.jsp for each portlet
      res = self.sendHttpRequest("#{url}html/portlet/#{portlet}/view.jsp")
      next if res.nil?
      next if res.code.nil?
      if res.code.to_i == 500
        installed_portlets << portlet
      end
    end
    installed_portlets
  end

  private

  #
  # Fetch URL
  #
  def self.sendHttpRequest(url)
    target = URI::parse(url)
    puts "Fetching #{target}" if $VERBOSE
    http = Net::HTTP.new(target.host, target.port)
    if target.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
    http.open_timeout = 20
    http.read_timeout = 20
    headers = {}
    headers['User-Agent'] = "LiferayScan/#{@version}"
    headers['Accept-Encoding'] = 'gzip,deflate'

    begin
      res = http.request(Net::HTTP::Get.new(target, headers.to_hash))
      if res['Content-Encoding'].eql?('gzip') && res.body
        begin
          sio = StringIO.new(res.body)
          gz = Zlib::GzipReader.new(sio)
          res.body = gz.read()
        rescue
        end
      end
    rescue Timeout::Error, Errno::ETIMEDOUT
      puts "- Error: Timeout retrieving #{target}" if $VERBOSE
    rescue => e
      puts "- Error: Could not retrieve URL #{target}\n#{e}" if $VERBOSE
    end
    return res
  end

end
