# Configuration

VERSION=$(shell ./genver.sh -r)
USELIBCONFIG=1	# Use libconfig? (necessary to use configuration files)
USELIBPCRE=1	# Use libpcre? (necessary to use regex probe)
USELIBWRAP?=	# Use libwrap?
USELIBCAP=	# Use libcap?
COV_TEST= 	# Perform test coverage?
PREFIX?=/usr
BINDIR?=$(PREFIX)/sbin
MANDIR?=$(PREFIX)/share/man/man8

MAN=sslh.8.gz	# man page name

# End of configuration -- the rest should take care of
# itself

ifneq ($(strip $(COV_TEST)),)
    CFLAGS_COV=-fprofile-arcs -ftest-coverage
endif

CC ?= gcc
CFLAGS ?=-Wall -g $(CFLAGS_COV)

LIBS=
OBJS=common.o sslh-main.o probe.o tls.o

ifneq ($(strip $(USELIBWRAP)),)
	LIBS:=$(LIBS) -lwrap
	CPPFLAGS+=-DLIBWRAP
endif

ifneq ($(strip $(USELIBPCRE)),)
	CPPFLAGS+=-DLIBPCRE
endif

ifneq ($(strip $(USELIBCONFIG)),)
	LIBS:=$(LIBS) -lconfig
	CPPFLAGS+=-DLIBCONFIG
endif

ifneq ($(strip $(USELIBCAP)),)
	LIBS:=$(LIBS) -lcap
	CPPFLAGS+=-DLIBCAP
endif

all: sslh $(MAN) echosrv

.c.o: *.h
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $<

version.h:
	./genver.sh >version.h

sslh: sslh-fork sslh-select

sslh-fork: version.h $(OBJS) sslh-fork.o Makefile common.h
	$(CC) $(CFLAGS) $(LDFLAGS) -o sslh-fork sslh-fork.o $(OBJS) $(LIBS)
	#strip sslh-fork

sslh-select: version.h $(OBJS) sslh-select.o Makefile common.h
	$(CC) $(CFLAGS) $(LDFLAGS) -o sslh-select sslh-select.o $(OBJS) $(LIBS)
	#strip sslh-select

echosrv: $(OBJS) echosrv.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o echosrv echosrv.o probe.o common.o tls.o $(LIBS)

$(MAN): sslh.pod Makefile
	pod2man --section=8 --release=$(VERSION) --center=" " sslh.pod | gzip -9 - > $(MAN)

# Create release: export clean tree and tag current
# configuration
release:
	git archive master --prefix="sslh-$(VERSION)/" | gzip > /tmp/sslh-$(VERSION).tar.gz

# generic install: install binary and man page
install: sslh $(MAN)
	mkdir -p $(DESTDIR)/$(BINDIR)
	mkdir -p $(DESTDIR)/$(MANDIR)
	install -p sslh-fork $(DESTDIR)/$(BINDIR)/sslh
	install -p -m 0644 $(MAN) $(DESTDIR)/$(MANDIR)/$(MAN)

# "extended" install for Debian: install startup script
install-debian: install sslh $(MAN)
	sed -e "s+^PREFIX=+PREFIX=$(PREFIX)+" scripts/etc.init.d.sslh > /etc/init.d/sslh
	chmod 755 /etc/init.d/sslh
	update-rc.d sslh defaults

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/sslh $(DESTDIR)$(MANDIR)/$(MAN) $(DESTDIR)/etc/init.d/sslh $(DESTDIR)/etc/default/sslh
	update-rc.d sslh remove

distclean: clean
	rm -f tags cscope.*

clean:
	rm -f sslh-fork sslh-select echosrv version.h $(MAN) *.o *.gcov *.gcno *.gcda *.png *.html *.css *.info

tags:
	ctags --globals -T *.[ch]

cscope:
	-find . -name "*.[chS]" >cscope.files
	-cscope -b -R

test:
	./t
