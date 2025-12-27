wl-ime-type(1)

# NAME

wl-ime-type - type text via a Wayland IME

# SYNOPSIS

*wl-ime-type* [options...] <text>

# DESCRIPTION

wl-ime-type inserts text in a Wayland client via the input-method-unstable-v2
protocol extension. This is a Zig port of the original wl-ime-type tool.

# OPTIONS

*-h, --help*
	Show help message and exit.

*-s, --seat* <name>
	Select a seat by name.

*--list-seats*
	List available seats and exit.

# EXAMPLES

Type text into the focused Wayland application:
	$ wl-ime-type "Hello, World!"

Select a specific seat:
	$ wl-ime-type -s seat0 "Hello"

List available seats:
	$ wl-ime-type --list-seats

# AUTHORS

This zig port is maintained by psynyde <pxynyde@proton.me>.
The original version is maintained by Simon Ser <contact@emersion.fr>. For more information, see
<https://github.com/psynyde/wl-ime-type>.

# LICENSE

This project is licensed under the BSD 2-Clause License.
