CFLAGS = -g -Wall -Wextra -Wno-unused-parameter
WAYLAND_SCANNER = $(shell pkg-config --variable=wayland_scanner wayland-scanner)

deps = wayland-client
depflags = $(shell pkg-config $(deps) --cflags --libs)

protocol_files = input-method-unstable-v2-protocol.h input-method-unstable-v2-protocol.c

all: wl-ime-type

wl-ime-type: main.c $(protocol_files)
	$(CC) $(CFLAGS) $(depflags) -o $@ $^

input-method-unstable-v2-protocol.h: protocol/input-method-unstable-v2.xml
	$(WAYLAND_SCANNER) client-header $< $@
input-method-unstable-v2-protocol.c: protocol/input-method-unstable-v2.xml
	$(WAYLAND_SCANNER) private-code $< $@

clean:
	$(RM) wl-ime-type $(protocol_files)
