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

```env
$ git clone git@github.com:soasme/rubyquiz.git /tmp/rubyquiz
$ cd /tmp/rubyquiz
```

## How to configure it?

RubyQuiz adopts `dotenv` as config reader and follows 12-factor config management strategy.
It reads configurations from environment.
You can simply put a `.env` file to configure application,
or set environment before launching application.
You can copy from template `.env.sample` as your configuration,
Don't forget to amend it:

```
$ cp .env.sample .env
$ vim .env # set your twitter application token and secret.
```

## How to run it in development environment?

After configuration settings done, you need to install all dependencies:

```bash
$ bundle install
```

After dependencies installed, you can start application in foreground (Type Ctrl-C to stop it):

```bash
$ bundle exec thin start
```

Or you can start application as daemon (don't forget to modify thin config file: `config/thin/example.yml`):

```bash
$ QUIZ_CONFIG=config/thin/example.yml ./bin/start_server
```

## How to deploy?

RubyQuiz use `Capistrano` as deploy framework. Follow steps below to deploy application:

1. Install dependencies in your server: rvm, ruby. You can use ansible/chef/puppet, or even run adhoc command.
2. Write stage configurations in `config/deploy`, for instance,`config/deploy/production.rb`.
3. Create && Edit && Upload `config/thin/production.yml`

    ```bash
    $ bundle exec thin config -C config/thin/production.yml
    $ vi config/thin/production.yml
    $ bundle exec cap production setup:upload_thin_yml
    00:00 setup:upload_thin_yml
    01 mkdir -p /var/www/rubyquiz/shared/config/thin
    ✔ 01 root@my_vanilla_server 0.499s
    Uploading /var/www/rubyquiz/shared/config/thin/production.yml 100.0%
    ```

4. Set environment. These environment items are listed in `.env.sample`.

    ```bash
    $ bundle exec cap production config:set TWEET_STREAM_SERIALIZER=file
    00:00 config:set
        Uploading /var/www/rubyquiz/shared/.env 100.0%
    $ ...
    ```

5. Deploy application

    ```bash
    $ bundle exec cap production deploy
    00:00 git:wrapper
        01 mkdir -p /tmp
        ✔ 01 root@my_vanilla_server 0.492s
        Uploading /tmp/git-ssh-rubyquiz-production-soasme.sh 100.0%
        02 chmod 700 /tmp/git-ssh-rubyquiz-production-soasme.sh
        ✔ 02 root@my_vanilla_server 0.471s
    00:02 git:check
        01 git ls-remote --heads git@github.com:soasme/rubyquiz.git
        01 e8a4f2206bd279806df58108a37833781fb0cf75	refs/heads/master
        ✔ 01 root@my_vanilla_server 1.767s
    00:03 deploy:check:directories
        01 mkdir -p /var/www/rubyquiz/shared /var/www/rubyquiz/releases
        ✔ 01 root@my_vanilla_server 0.450s
    00:04 deploy:check:linked_dirs
        01 mkdir -p /var/www/rubyquiz/shared/log /var/www/rubyquiz/shared/tmp/pids /var/www/rubyquiz/shared/data
        ✔ 01 root@my_vanilla_server 0.472s
    00:06 git:clone
        The repository mirror is at /var/www/rubyquiz/repo
    00:06 git:update
        01 git remote update --prune
        01 Fetching origin
        ✔ 01 root@my_vanilla_server 1.785s
    00:08 git:create_release
        01 mkdir -p /var/www/rubyquiz/releases/20161213033240
        ✔ 01 root@my_vanilla_server 0.455s
        02 git archive master | /usr/bin/env tar -x -f - -C /var/www/rubyquiz/releases/20161213033240
        ✔ 02 root@my_vanilla_server 0.485s
    00:11 deploy:set_current_revision
        01 echo "e8a4f2206bd279806df58108a37833781fb0cf75" >> REVISION
        ✔ 01 root@my_vanilla_server 0.476s
    00:11 deploy:symlink:linked_dirs
        01 mkdir -p /var/www/rubyquiz/releases/20161213033240 /var/www/rubyquiz/releases/20161213033240/tmp
        ✔ 01 root@my_vanilla_server 0.440s
        02 ln -s /var/www/rubyquiz/shared/log /var/www/rubyquiz/releases/20161213033240/log
        ✔ 02 root@my_vanilla_server 0.491s
        03 ln -s /var/www/rubyquiz/shared/tmp/pids /var/www/rubyquiz/releases/20161213033240/tmp/pids
        ✔ 03 root@my_vanilla_server 0.500s
        04 ln -s /var/www/rubyquiz/shared/data /var/www/rubyquiz/releases/20161213033240/data
        ✔ 04 root@my_vanilla_server 0.450s
    00:18 bundler:install
        01 /usr/local/rvm/bin/rvm default do bundle install --path /var/www/rubyquiz/shared/bundle --without development …
        ✔ 01 root@my_vanilla_server 5.071s
    00:23 deploy:symlink:release
        01 ln -s /var/www/rubyquiz/releases/20161213033240 /var/www/rubyquiz/releases/current
        ✔ 01 root@my_vanilla_server 0.473s
        02 mv /var/www/rubyquiz/releases/current /var/www/rubyquiz
        ✔ 02 root@my_vanilla_server 0.452s
    00:24 deploy:restart_thin
        01 lsof -i:5000 -t | xargs -I {} kill -9 {}
        ✔ 01 root@my_vanilla_server 0.471s
    00:25 thin:start
        01 /usr/local/rvm/bin/rvm default do bundle exec thin start -C /var/www/rubyquiz/shared/config/thin/production.yml
        01 Deleting stale PID file /var/www/rubyquiz/shared/tmp/pids/thin.pid
        ✔ 01 root@my_vanilla_server 1.525s
    00:27 deploy:cleanup
        Keeping 5 of 6 deployed releases on my_vanilla_server
        01 rm -rf /var/www/rubyquiz/releases/20161213031149
        ✔ 01 root@my_vanilla_server 0.471s
    00:28 deploy:log_revision
        01 echo "Branch master (at e8a4f2206bd279806df58108a37833781fb0cf75) deployed as release 20161213033240 by soasme…
        ✔ 01 root@my_vanilla_server 0.476s
    ```

    ## How to test it?

Run:

```bash
$ bundle exec rake
........................

Finished in 0.08214 seconds (files took 0.87728 seconds to load)
24 examples, 0 failures
```
