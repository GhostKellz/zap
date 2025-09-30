const std = @import("std");

test "arraylist unmanaged" {
    var list = std.ArrayListUnmanaged(u8){};
    defer list.deinit(std.testing.allocator);

    try list.append(std.testing.allocator, 'a');
    try list.appendSlice(std.testing.allocator, "bc");

    try std.testing.expectEqualStrings("abc", list.items);
}

fn escapeJsonString(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out = std.ArrayListUnmanaged(u8){};
    defer out.deinit(allocator);

    try out.append(allocator, '"');
    for (input) |c| switch (c) {
        '\\' => try out.appendSlice(allocator, "\\\\"),
        '"' => try out.appendSlice(allocator, "\\\""),
        '\n' => try out.appendSlice(allocator, "\\n"),
        '\r' => try out.appendSlice(allocator, "\\r"),
        '\t' => try out.appendSlice(allocator, "\\t"),
        else => try out.append(allocator, c),
    };
    try out.append(allocator, '"');

    return out.toOwnedSlice(allocator);
}

test "escape json string" {
    const escaped = try escapeJsonString(std.testing.allocator, "foo\n\"bar\"");
    defer std.testing.allocator.free(escaped);

    try std.testing.expectEqualStrings("\"foo\\n\\\"bar\\\"\"", escaped);
}

fn appendJsonFieldInt(allocator: std.mem.Allocator, builder: *std.ArrayListUnmanaged(u8), first: *bool, name: []const u8, value: anytype) !void {
    const text = try std.fmt.allocPrint(allocator, "{d}", .{value});
    defer allocator.free(text);
    try appendJsonFieldRaw(allocator, builder, first, name, text);
}

fn appendJsonFieldRaw(allocator: std.mem.Allocator, builder: *std.ArrayListUnmanaged(u8), first: *bool, name: []const u8, raw: []const u8) !void {
    if (!first.*) try builder.append(allocator, ',');
    first.* = false;

    const escaped_name = try escapeJsonString(allocator, name);
    defer allocator.free(escaped_name);

    try builder.appendSlice(allocator, escaped_name);
    try builder.append(allocator, ':');
    try builder.appendSlice(allocator, raw);
}

fn appendJsonFieldString(allocator: std.mem.Allocator, builder: *std.ArrayListUnmanaged(u8), first: *bool, name: []const u8, value: []const u8) !void {
    const escaped = try escapeJsonString(allocator, value);
    defer allocator.free(escaped);
    try appendJsonFieldRaw(allocator, builder, first, name, escaped);
}

fn appendJsonFieldBool(allocator: std.mem.Allocator, builder: *std.ArrayListUnmanaged(u8), first: *bool, name: []const u8, value: bool) !void {
    const raw = if (value) "true" else "false";
    try appendJsonFieldRaw(allocator, builder, first, name, raw);
}

fn appendJsonFieldFloat(allocator: std.mem.Allocator, builder: *std.ArrayListUnmanaged(u8), first: *bool, name: []const u8, value: f64) !void {
    const text = try std.fmt.allocPrint(allocator, "{d}", .{value});
    defer allocator.free(text);
    try appendJsonFieldRaw(allocator, builder, first, name, text);
}

test "append int" {
    var builder = std.ArrayListUnmanaged(u8){};
    defer builder.deinit(std.testing.allocator);
    var first = true;

    try builder.append(std.testing.allocator, '{');
    try appendJsonFieldInt(std.testing.allocator, &builder, &first, "num", 42);
    try appendJsonFieldString(std.testing.allocator, &builder, &first, "str", "hi");
    try appendJsonFieldBool(std.testing.allocator, &builder, &first, "flag", true);
    try appendJsonFieldFloat(std.testing.allocator, &builder, &first, "temp", 0.3);
    try builder.append(std.testing.allocator, '}');

    const json = try builder.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expectEqualStrings("{\"num\":42,\"str\":\"hi\",\"flag\":true,\"temp\":0.3}", json);
}
