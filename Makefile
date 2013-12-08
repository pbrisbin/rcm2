NAME    = rcm2
VERSION = 0.0.1
RELEASE = 1
AUTHOR  = pbrisbin
URL     = https://github.com/$(AUTHOR)/$(NAME)

PREFIX ?= /usr/local

install:
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	mkdir -p $(DESTDIR)$(PREFIX)/share/rcm
	install -D -m755 bin/lsrc bin/mkrc bin/rcdn bin/rcup \
	  $(DESTDIR)$(PREFIX)/bin/
	install -D -m644 share/rcm/compat.sh share/rcm/rcm.sh \
	  $(DESTDIR)$(PREFIX)/share/rcm/

uninstall:
	$(RM) \
	  $(DESTDIR)$(PREFIX)/bin/lsrc \
	  $(DESTDIR)$(PREFIX)/bin/mkrc \
	  $(DESTDIR)$(PREFIX)/bin/rcdn \
	  $(DESTDIR)$(PREFIX)/bin/rcup
	$(RM) -r $(DESTDIR)$(PREFIX)/share/rcm

.PHONY: install uninstall
