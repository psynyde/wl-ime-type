const std = @import("std");
const wayland = @import("wayland");

const wl = wayland.client.wl;
const input = wayland.client.zwp;

const Client = struct {
    input_manager: ?*input.InputMethodManagerV2 = null,
    seat: ?*wl.Seat = null,

    ime: ?*input.InputMethodV2 = null,
    ime_active: bool = false,
    ime_unavailable: bool = false,
    serial: u32 = 0,
};

fn registry_listener(
    registry: *wl.Registry,
    event: wl.Registry.Event,
    client: *Client,
) void {
    switch (event) {
        .global => |global| {
            if (std.mem.orderZ(u8, global.interface, input.InputMethodManagerV2.interface.name) == .eq) {
                client.input_manager =
                    registry.bind(global.name, input.InputMethodManagerV2, 1) catch return;
            } else if (std.mem.orderZ(u8, global.interface, wl.Seat.interface.name) == .eq) {
                client.seat =
                    registry.bind(global.name, wl.Seat, 2) catch return;
            }
        },
        .global_remove => {},
    }
}

fn ime_listener(
    _: *input.InputMethodV2,
    event: input.InputMethodV2.Event,
    client: *Client,
) void {
    switch (event) {
        .activate => client.ime_active = true,
        .deactivate => client.ime_active = false,
        .done => client.serial += 1,
        .unavailable => client.ime_unavailable = true,

        // required but unused
        .surrounding_text => {},
        .text_change_cause => {},
        .content_type => {},
    }
}

fn readInput(allocator: std.mem.Allocator) ![]u8 {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 1) {
        return allocator.dupe(u8, args[1]);
    }

    const stdin_file = std.fs.File.stdin();
    if (!stdin_file.isTty()) {
        var buf: [4096]u8 = undefined;
        var reader = stdin_file.reader(&buf);
        var reader_io = &reader.interface;

        const stdin_text = try reader_io.allocRemaining(allocator, .unlimited);

        if (stdin_text.len == 0)
            return error.EmptyInput;

        return stdin_text;
    }
    return error.NoInputProvided;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const text = try readInput(allocator);
    defer allocator.free(text);

    const c_text = try allocator.dupeZ(u8, text);
    defer allocator.free(c_text);

    if (c_text.len == 0) return error.EmptyInput;

    const display = try wl.Display.connect(null);
    defer display.disconnect();

    const registry = try display.getRegistry();
    defer registry.destroy();

    var client = Client{};

    registry.setListener(*Client, registry_listener, &client);
    if (display.roundtrip() != .SUCCESS)
        return error.RoundTripFailed;

    const input_manager = client.input_manager orelse return error.NoInputManager;
    const seat = client.seat orelse return error.NoSeat;

    const ime = try input_manager.getInputMethod(seat);
    client.ime = ime;

    ime.setListener(*Client, ime_listener, &client);

    // wait for activation
    while (!client.ime_active and !client.ime_unavailable) {
        if (display.dispatch() != .SUCCESS)
            return error.DispatchFailed;
    }

    if (client.ime_unavailable)
        return error.ImeUnavailable;

    ime.commitString(c_text);
    ime.commit(client.serial);

    if (display.roundtrip() != .SUCCESS)
        return error.RoundTripFailed;

    ime.destroy();
    input_manager.destroy();
}
