dev-deamon:
	bundle exec thin -P /tmp/rubyquiz.pid -l /tmp/rubyquiz.log -d start

dev-foreground:
	bundle exec thin start
