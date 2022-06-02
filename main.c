#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>
#include "input-method-unstable-v2-protocol.h"

static const char *seat_name = NULL;

static struct zwp_input_method_manager_v2 *ime_manager = NULL;
static struct wl_seat *seat = NULL;

static bool ime_active = false;
static bool ime_unavailable = false;
static uint32_t ime_serial = 0;

static void noop() {}

static void ime_handle_activate(void *data, struct zwp_input_method_v2 *ime)
{
	ime_active = true;
}

static void ime_handle_deactivate(void *data, struct zwp_input_method_v2 *ime)
{
	ime_active = false;
}

static void ime_handle_done(void *data, struct zwp_input_method_v2 *ime)
{
	ime_serial++;
}

static void ime_handle_unavailable(void *data, struct zwp_input_method_v2 *ime)
{
	ime_unavailable = true;
}

static const struct zwp_input_method_v2_listener ime_listener = {
	.activate = ime_handle_activate,
	.deactivate = ime_handle_deactivate,
	.surrounding_text = noop,
	.text_change_cause = noop,
	.content_type = noop,
	.done = ime_handle_done,
	.unavailable = ime_handle_unavailable,
};

static void seat_handle_name(void *data, struct wl_seat *s, const char *name)
{
	if (strcmp(name, seat_name) == 0) {
		seat = s;
	} else {
		wl_seat_destroy(s);
	}
}

static const struct wl_seat_listener seat_listener = {
	.capabilities = noop,
	.name = seat_handle_name,
};

static void registry_handle_global(void *data, struct wl_registry *registry, uint32_t name, const char *iface, uint32_t version)
{
	if (strcmp(iface, zwp_input_method_manager_v2_interface.name) == 0) {
		ime_manager = wl_registry_bind(registry, name, &zwp_input_method_manager_v2_interface, 1);
	} else if (seat == NULL && strcmp(iface, wl_seat_interface.name) == 0) {
		struct wl_seat *s = wl_registry_bind(registry, name, &wl_seat_interface, 2);
		if (seat_name == NULL) {
			seat = s;
		} else {
			wl_seat_add_listener(s, &seat_listener, NULL);
		}
	}
}

static const struct wl_registry_listener registry_listener = {
	.global = registry_handle_global,
	.global_remove = noop,
};

static const char usage[] = "usage: wl-ime-type [options...] <text>\n";

int main(int argc, char *argv[])
{
	int opt;
	while ((opt = getopt(argc, argv, "hs:")) != -1) {
		switch (opt) {
		case 's':
			seat_name = optarg;
			break;
		default:
			fprintf(stderr, "%s", usage);
			return opt == 'h' ? 0 : 1;
		}
	}

	if (optind != argc - 1) {
		fprintf(stderr, "%s", usage);
		return 1;
	}

	const char *text = argv[optind];

	struct wl_display *display = wl_display_connect(NULL);
	if (display == NULL) {
		fprintf(stderr, "wl_display_connect failed\n");
		return 1;
	}

	struct wl_registry *registry = wl_display_get_registry(display);
	wl_registry_add_listener(registry, &registry_listener, NULL);
	wl_display_roundtrip(display);
	wl_registry_destroy(registry);

	if (seat_name != NULL) {
		// Second roundtrip to fetch seat names
		wl_display_roundtrip(display);
	}

	if (seat == NULL) {
		if (seat_name == NULL) {
			fprintf(stderr, "No seat found\n");
		} else {
			fprintf(stderr, "No seat found with the name '%s'\n", seat_name);
		}
		return 1;
	}
	if (ime_manager == NULL) {
		fprintf(stderr, "Compositor doesn't support input-method-unstable-v2\n");
		return 1;
	}

	struct zwp_input_method_v2 *ime = zwp_input_method_manager_v2_get_input_method(ime_manager, seat);
	zwp_input_method_v2_add_listener(ime, &ime_listener, NULL);

	// Wait for the compositor to activate the IME
	while (!ime_active && !ime_unavailable) {
		if (wl_display_dispatch(display) < 0) {
			fprintf(stderr, "wl_display_dispatch failed\n");
			return 1;
		}
	}
	if (ime_unavailable) {
		fprintf(stderr, "IME is unavailable (maybe another IME is active?)\n");
		return 1;
	}

	zwp_input_method_v2_commit_string(ime, text);
	zwp_input_method_v2_commit(ime, ime_serial);

	// We'll exit right afterwards, so ensure the compositor has received our
	// queued requests
	wl_display_roundtrip(display);

	zwp_input_method_v2_destroy(ime);
	zwp_input_method_manager_v2_destroy(ime_manager);
	wl_display_disconnect(display);

	return 0;
}
