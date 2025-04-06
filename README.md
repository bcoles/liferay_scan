# LiferayScan

## Description

LiferayScan is a simple remote scanner for Liferay Portal.

## Installation

Install from RubyGems.org:

```
gem install liferay_scan
```

Install from GitHub:

```
git clone https://github.com/bcoles/liferay_scan
cd liferay_scan
bundle install
gem build liferay_scan.gemspec
gem install --local liferay_scan-0.0.2.gem
```

## Usage (command line)

```
% Usage: liferay-scan [options]
    -u, --url URL                    Liferay URL to scan
    -s, --skip                       Skip check for Liferay
    -i, --insecure                   Skip SSL/TLS validation
        --enum-users                 Enumerate users
    -v, --verbose                    Enable verbose output
    -h, --help                       Show this help
```

## Usage (ruby)

```ruby
#!/usr/bin/env ruby
require 'liferay_scan'
url = 'https://liferay.example.local/'
LiferayScan::detectLiferay(url)                    # Check if a URL is Liferay (using all methods)
LiferayScan::detectLiferayFromLogin(url)           # Check if a URL is Liferay (using login page)
LiferayScan::detectLiferayFromHome(url)            # Check if a URL is Liferay (using home page)
LiferayScan::userRegistration(url)                 # Check if user registration if enabled
LiferayScan::ssoAuthEnabled(url)                   # Check if Single SignOn (SSO) authentication is enabled
LiferayScan::remoteSoapApi(url)                    # Check if SOAP API is accessible
LiferayScan::remoteJsonApi(url)                    # Check if JSON API is accessible
LiferayScan::passwordResetEnabled(url)             # Check if Forgot Password is enabled
LiferayScan::passwordResetUsesCaptcha(url)         # Check if Forgot Password uses CAPTCHA
LiferayScan::getVersion(url)                       # Retrieve Liferay version (using all methods)
LiferayScan::getVersionFromLogin(url)              # Retrieve Liferay version (from login page)
LiferayScan::getVersionFromGuestHome(url)          # Retrieve Liferay version (from guest home page)
LiferayScan::getServerVersion(url)                 # Retrieve server version (from server error page)
LiferayScan::getClientIpAddress(url)               # Retrieve client IP address (from server error page)
LiferayScan::getLanguage(url)                      # Retrieve default language (ie, en_US)
LiferayScan::getOrganisationEmail(url)             # Retrieve organisation email address domain (ie, @liferay.com)
LiferayScan::getUsersFromSearch(url)               # Retrieve user names from open search
LiferayScan::enumerateUsers(url)                   # Enumerate some user names using blog RSS feed URLs
```
