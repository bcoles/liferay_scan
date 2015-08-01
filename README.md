# LiferayScan

## Description

LiferayScan is a simple remote scanner for Liferay Portal.

## Installation

```
bundle install
gem build LiferayScan.gemspec
gem install --local LiferayScan-0.0.1.gem
```

## Usage (command line)

```
% LiferayScan -h
Usage: LiferayScan <url> [options]
    -u, --url URL                    Liferay URL to scan
    -s, --skip                       Skip check for Liferay
    -v, --verbose                    Enable verbose output
    -h, --help                       Show this help

```

## Usage (ruby)

```
require 'LiferayScan'
is_liferay = LiferayScan::isLiferay(url)            # Check if a URL is Liferay
version    = LiferayScan::getVersion(url)           # Get Liferay version
language   = LiferayScan::getLanguage(url)          # Get default language (ie, en_US)
domain     = LiferayScan::getOrganisationEmail(url) # Get organisation email address domain (ie, @liferay.com)
register   = LiferayScan::userRegistration(url)     # Check if user registration if enabled
soap_api   = LiferayScan::remoteSoapApi(url)        # Check if SOAP API is accessible
json_api   = LiferayScan::remoteJsonApi(url)        # Check if JSON API is accessible
captcha    = LiferayScan::usesCaptcha(url)          # Check if Forgot Password uses CAPTCHA
users      = LiferayScan::enumerateUsers(url)       # Enumerate some user names from open search and blog rss
portlets   = LiferayScan::enumeratePortlets(url)    # Enumerate installed portlets
```

