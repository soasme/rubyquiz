dev-deamon:
	thin -P /tmp/rubyquiz.pid -l /tmp/rubyquiz.log -d start

dev-foreground:
	thin start
