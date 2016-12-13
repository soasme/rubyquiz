# RubyQuiz

## What is it?

The following exercise is meant to assess the ability to provide and consume web
API from a ruby application. A successful candidate has to produce an artefact 
that can be distributed, tested and consumed by third parties and fulfil the 
following functional requirements:

- The software has to run as a Linux daemon (RedHat / Centos)
- The software exposes a ReST API which tells the process to consumer a certain
  hashtag on Twitter.  ( GET/consumer/HASHTAG/start, GET /consumer/HASHTAG/status,
  GET /consumer/HASHTAG/stop)
- For each hashtag being followed the daemons appends in realtime the content of
  the post to a file. Each hashtag will be dumped in it’s own file.
- The daemon will talk to Twitter Streaming API, no external libraries are allowed.
- The software should avoid blocking calls.

## How to get source?

You can use `git` to clone it from GitHub:

    $ git clone git@github.com:soasme/rubyquiz.git /tmp/rubyquiz
    $ cd /tmp/rubyquiz

## How to configure it?

RubyQuiz adopts `dotenv` as config reader and follows 12-factor config management strategy.
It read configurations from environment. You can simple put a `.env` file to configure it,
or just simple set environment. You can copy template `.env.sample` as your configuration,
and don't forget to amend it:

    $ cp .env.sample .env
    $ vim .env # set your twitter application token and secret.

## How to run it in development environment?

After configuration settings done, you need to install all dependencies:

    $ bundle install

After dependencies installed, you can start application in foreground (Type Ctrl-C to
stop it):

    $ bundle exec thin start

Or you can start application as daemon (don't forget to amend it to your environment):

    $ QUIZ_CONFIG=config/example.yml ./bin/start_server

## How to run it in production environment?

- Write a `/etc/thin/config/rubyquiz-production.yml` file, similar to `config/example.yml`.
- Deploy `config/thin.service` as one of service of `systemd`.
- Manage thin process as normal service: 
    - Start service: `$ systemctl start thin.service`
    - Stop service: `$ systemctl stop thin.service`
    - View service status: `$ systemctl status thin.service`
    - View service log: `$ journalctl -u thin.service`

## How to deploy?

RubyQuiz use `Capistrano` as deploy tool. Make sure your configurations have applied
to servers:

    $ bundle exec cap production deploy

## How to test it?

Run:

    $ bundle exec rake
