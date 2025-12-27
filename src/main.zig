const std = @import("std");
const builtin = @import("builtin");
const wayland = @import("wayland");

const wl = wayland.client.wl;
const input = wayland.client.zwp;

const SeatInfo = struct {
    seat: *wl.Seat,
    name: []const u8,
};

const Client = struct {
    allocator: std.mem.Allocator,

    input_manager: ?*input.InputMethodManagerV2 = null,

    seats: std.ArrayList(SeatInfo),

    ime: ?*input.InputMethodV2 = null,
    ime_active: bool = false,
    ime_unavailable: bool = false,
    serial: u32 = 0,
};

const Options = struct {
    show_help: bool = false,
    list_seats: bool = false,
    seat_name: ?[]const u8 = null,
};

fn parseOptions(allocator: std.mem.Allocator) !Options {
    var opts = Options{};
    var it = try std.process.argsWithAllocator(allocator);
    defer it.deinit();

    _ = it.next(); // argv[0]

    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            opts.show_help = true;
        } else if (std.mem.eql(u8, arg, "--list-seats")) {
            opts.list_seats = true;
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--seat")) {
            opts.seat_name = it.next() orelse return error.MissingSeatName;
        } else {
            break;
        }
    }
    return opts;
}

fn seatListener(
    seat: *wl.Seat,
    event: wl.Seat.Event,
    client: *Client,
) void {
    switch (event) {
        .name => |name| {
            const duped = client.allocator.dupe(
                u8,
                std.mem.span(name.name),
            ) catch return;

            client.seats.append(client.allocator, .{
                .name = duped,
                .seat = seat,
            }) catch {};
        },
        .capabilities => {},
    }
}

fn registryListener(
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
                const seat =
                    registry.bind(global.name, wl.Seat, 2) catch return;
                seat.setListener(*Client, seatListener, client);
            }
        },
        .global_remove => {},
    }
}

fn imeListener(
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

fn printSeats(stdout: *std.Io.Writer, seats: []const SeatInfo, default_seat: ?*wl.Seat) !void {
    if (seats.len == 0) {
        try stdout.print("No seats found\n", .{});
        try stdout.flush();
        return;
    }

    try stdout.print("Available seats:\n", .{});

    for (seats) |s| {
        const is_default = default_seat != null and s.seat == default_seat.?;
        try stdout.print(
            "  {s}{s}\n",
            .{ s.name, if (is_default) " (default)" else "" },
        );
    }
    try stdout.flush();
}

fn printHelp(stdout: *std.Io.Writer) !void {
    try stdout.print(
        \\Usage: wl-ime-type [options] <text>
        \\
        \\Options:
        \\  -h, --help           Show this help message
        \\  -s, --seat <name>    Select seat by name
        \\      --list-seats     List available seats and exit
        \\
    , .{});
    try stdout.flush();
}

fn selectSeat(
    seats: []const SeatInfo,
    seat_name: ?[]const u8,
) !*wl.Seat {
    if (seats.len == 0)
        return error.NoSeat;

    if (seat_name == null)
        return seats[0].seat;

    for (seats) |s| {
        if (std.mem.eql(u8, s.name, seat_name.?))
            return s.seat;
    }

    return error.SeatNotFound;
}

fn readInput(allocator: std.mem.Allocator) ![]u8 {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 1) {
        return allocator.dupe(u8, args[args.len - 1]);
    }

    const stdin_file = std.fs.File.stdin();
    if (!stdin_file.isTty()) {
        var buf: [4096]u8 = undefined;
        var reader = stdin_file.reader(&buf);
        var iface = &reader.interface;

        const text = try iface.allocRemaining(allocator, .unlimited);
        if (text.len == 0)
            return error.EmptyInput;

        return text;
    }
    return error.NoInputProvided;
}

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
pub fn main() !void {
    const allocator = comptime alloc: {
        if (builtin.mode == .Debug) break :alloc debug_allocator.allocator();
        break :alloc std.heap.smp_allocator;
    };
    defer if (builtin.mode == .Debug) {
        _ = debug_allocator.deinit();
    };

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const opts = try parseOptions(allocator);

    const display = try wl.Display.connect(null);
    defer display.disconnect();

    const registry = try display.getRegistry();
    defer registry.destroy();

    var client = Client{
        .allocator = allocator,
        .seats = .empty,
    };
    defer {
        for (client.seats.items) |s|
            allocator.free(s.name);
        client.seats.deinit(allocator);
    }

    registry.setListener(*Client, registryListener, &client);

    // First roundtrip: globals
    _ = display.roundtrip();
    // Second roundtrip: seat names
    _ = display.roundtrip();

    const default_seat =
        if (client.seats.items.len > 0) client.seats.items[0].seat else null;

    if (opts.show_help) {
        try printHelp(stdout);
        return;
    }

    if (opts.list_seats) {
        try printSeats(stdout, client.seats.items, default_seat);
        return;
    }

    const text = readInput(allocator) catch |err| {
        switch (err) {
            error.NoInputProvided => {
                try printHelp(stdout);
                return;
            },
            else => return err,
        }
    };
    defer allocator.free(text);

    const c_text = try allocator.dupeZ(u8, text);
    defer allocator.free(c_text);

    const seat = try selectSeat(client.seats.items, opts.seat_name);

    const input_manager = client.input_manager orelse
        return error.NoInputManager;

    const ime = try input_manager.getInputMethod(seat);
    client.ime = ime;

    ime.setListener(*Client, imeListener, &client);

    // Wait for activation
    while (!client.ime_active and !client.ime_unavailable) {
        if (display.dispatch() != .SUCCESS)
            return error.DispatchFailed;
    }

    if (client.ime_unavailable)
        return error.ImeUnavailable;

    ime.commitString(c_text);
    ime.commit(client.serial);

    _ = display.roundtrip();

    ime.destroy();
    input_manager.destroy();
}
