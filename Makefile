PREFIX ?= $(HOME)/.local

install:
	mkdir -p $(PREFIX)/bin
	cp gitlab-clone.sh $(PREFIX)/bin/gitlab-clone
	chmod +x $(PREFIX)/bin/gitlab-clone

uninstall:
	rm -f $(PREFIX)/bin/gitlab-clone
