# Add IMAP Support to your Helpy

This extension adds support for IMAP mail servers.  Once you have configured the
server address and set up the rake task, Helpy will periodically fetch email from
your mail server and convert any messages found into tickets.

## Installation

Add this to your Gemfile:

```
gem 'helpy_imap', git: 'https://github.com/scott/helpy_imap', branch: 'master'
```

and then run:

```
bundle install
```

## Running the mail fetcher:

To fetch email periodically, you must run the mailman process. Included in this
package is a rake task to help with this. You can either run this periodically with
a cronjob, or pass a parameter to the rake job to specify a polling frequency:

Run once:

```
bundle exec rake helpy:mailman
```

Polling (every 60 seconds):

```
bundle exec rake helpy:mailman mail_interval=60
```

## Credits

The majority of the code used here was originally contributed to Helpy by @janrenz in PR
#148. (https://github.com/helpyio/helpy/pull/148)

## How to configure for gmail IMAP

1. Turn on IMAP for your gmail account
2. In Helpy, use the following configurations:
