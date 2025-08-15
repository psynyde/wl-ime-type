CFLAGS = -g -Wall -Wextra -Wno-unused-parameter
WAYLAND_SCANNER = $(shell pkg-config --variable=wayland_scanner wayland-scanner)
SCDOC = scdoc
PREFIX ?= /usr/local
BINDIR ?= bin
MANDIR ?= share/man

deps = wayland-client
depflags = $(shell pkg-config $(deps) --cflags --libs)

protocol_files = input-method-unstable-v2-protocol.h input-method-unstable-v2-protocol.c

all: wl-ime-type wl-ime-type.1

wl-ime-type: main.c $(protocol_files)
	$(CC) $(CFLAGS) -o $@ $^ $(depflags)

input-method-unstable-v2-protocol.h: protocol/input-method-unstable-v2.xml
	$(WAYLAND_SCANNER) client-header $< $@
input-method-unstable-v2-protocol.c: protocol/input-method-unstable-v2.xml
	$(WAYLAND_SCANNER) private-code $< $@

wl-ime-type.1: wl-ime-type.1.scd
	$(SCDOC) < $< > $@

.PHONY: install clean

install:
	install -Dm755 wl-ime-type -t $(DESTDIR)$(PREFIX)/$(BINDIR)/
	install -Dm644 wl-ime-type.1 -t $(DESTDIR)$(PREFIX)/$(MANDIR)/man1

clean:
	$(RM) wl-ime-type wl-ime-type.1 $(protocol_files)
