PREFIX ?= $(HOME)/.local

install:
	mkdir -p $(PREFIX)/bin
	chmod +x $(CURDIR)/gitlab-clone.sh
	ln -sf $(CURDIR)/gitlab-clone.sh $(PREFIX)/bin/gitlab-clone

uninstall:
	rm -f $(PREFIX)/bin/gitlab-clone
