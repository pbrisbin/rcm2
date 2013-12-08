NAME    = rcm2
VERSION = 0.0.1
RELEASE = 1
AUTHOR  = pbrisbin
URL     = https://github.com/$(AUTHOR)/$(NAME)

PREFIX ?= /usr/local

install:
	install -D -m755 bin/lsrc $(DESTDIR)$(PREFIX)/bin/lsrc
	install -D -m755 bin/mkrc $(DESTDIR)$(PREFIX)/bin/mkrc
	install -D -m755 bin/rcdn $(DESTDIR)$(PREFIX)/bin/rcdn
	install -D -m755 bin/rcup $(DESTDIR)$(PREFIX)/bin/rcup
	install -D -m644 share/rcm/rcm.sh $(DESTDIR)$(PREFIX)/share/rcm/rcm.sh

uninstall:
	$(RM) \
	  $(DESTDIR)$(PREFIX)/bin/lsrc \
	  $(DESTDIR)$(PREFIX)/bin/mkrc \
	  $(DESTDIR)$(PREFIX)/bin/rcdn \
	  $(DESTDIR)$(PREFIX)/bin/rcup
	$(RM) -r $(DESTDIR)$(PREFIX)/share/rcm

.PHONY: install uninstall
