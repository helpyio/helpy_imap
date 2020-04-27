# Add IMAP Support to your Helpy

This extension adds support for IMAP/POP3 mail servers. A new settings panel has been added, 
and a rake task is provided to fetch email from the mailserver periodically.

## Installation

Add this to your Gemfile:

```
gem 'helpy_imap', git: 'https://github.com/helpyio/helpy_imap', branch: 'master'
```

and then run:

```
bundle install
```

## Running the mail fetcher:

To fetch email periodically, you must configure CRON to periodically call the included
rake task.

Run once:

```
bundle exec rake helpy:fetch_mail
```

## Credits

The majority of the code used here was originally contributed to Helpy by @janrenz in PR
#148. (https://github.com/helpyio/helpy/pull/148)  

## How to configure for gmail IMAP

1. Turn on IMAP for your gmail account
2. In Helpy, use the following configurations:

server: imap.gmail.com
login: your.email@gmail.com
password: your_password
security: SSL/TLS
port: 993