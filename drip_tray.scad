// Drip tray with a removable hexagonal grid insert.
// Coordinates: x = width, y = length, z = up. Tray origin at its outer corner.

/* [View] */
part = "assembly"; // [assembly, exploded, section, tray, grid, grid_print, print_plate]

/* [Tray] */
tray_size = [220, 320, 10]; // outer width, length, height
wall = 2;
corner_radius = 5; // vertical corners and bottom edges

/* [Grid] */
clearance = 0.5; // gap between grid and tray wall, all around
grid_thickness = 4; // hex plate, measured down from the top
rim_width = 3; // solid outline around the hex pattern
hex_radius = 6; // circumradius of one hex hole
hex_web = 1.6; // material between neighbouring hex holes
leg_spacing = 40; // maximum distance between legs
leg_foot = 2; // leg radius where it stands on the tray floor
finger_notches = true; // half-circle notch on each short edge to lift the grid out
notch_radius = 15;

/* [Hidden] */
$fn = 48;
tray_color = "SlateGray";
grid_color = "Orange";
print_gap = 10; // between the parts on print_plate

cavity_size = [tray_size.x - 2 * wall, tray_size.y - 2 * wall];
cavity_radius = corner_radius - wall;
// The grid stands on the tray floor and reaches up to the tray rim.
grid_size = [cavity_size.x - 2 * clearance, cavity_size.y - 2 * clearance, tray_size.z - wall];
grid_radius = cavity_radius - clearance;
leg_height = grid_size.z - grid_thickness;
notch_centers = !finger_notches ? []
    : grid_size.x <= grid_size.y
    ? [[grid_size.x / 2, 0], [grid_size.x / 2, grid_size.y]]
    : [[0, grid_size.y / 2], [grid_size.x, grid_size.y / 2]];

hex_pitch = 2 * hex_radius * cos(30) + hex_web; // centre distance of neighbouring holes
hex_column = hex_pitch * cos(30);
hex_count = [ceil(grid_size.x / 2 / hex_column), ceil(grid_size.y / 2 / hex_pitch)];
hex_centers = [
    for (i = [-hex_count.x : hex_count.x], j = [-hex_count.y : hex_count.y])
        [grid_size.x / 2 + i * hex_column, grid_size.y / 2 + (j + abs(i) % 2 / 2) * hex_pitch]
];
// Points where three walls meet: the left and right corner of every hole.
junctions = [for (c = hex_centers, side = [-1, 1]) c + [side * hex_pitch / sqrt(3), 0]];

// Legs, including their fillet, stay clear of the rounded floor edge of the
// tray and of the finger notches.
leg_reach = leg_foot + leg_height; // footprint radius where the leg meets the plate
leg_inset = grid_radius + leg_reach;
leg_candidates = [
    for (p = junctions)
        if (p.x >= leg_inset && p.x <= grid_size.x - leg_inset
            && p.y >= leg_inset && p.y <= grid_size.y - leg_inset
            && [for (c = notch_centers) if (norm(p - c) < notch_radius + leg_reach) c] == []) p
];

// Evenly spaced from leg_inset to length - leg_inset.
function leg_row(length) =
    let (span = length - 2 * leg_inset, n = max(1, ceil(span / leg_spacing)))
    [for (k = [0 : n]) leg_inset + k * span / n];

function nearest(points, target) =
    let (distances = [for (p = points) norm(p - target)])
    points[search(min(distances), distances)[0]];

leg_positions = [
    for (x = leg_row(grid_size.x), y = leg_row(grid_size.y)) nearest(leg_candidates, [x, y])
];

assert(corner_radius <= tray_size.z, "corner_radius must not exceed the tray height");
assert(grid_radius > 0, "corner_radius must exceed wall + clearance");
assert(leg_height > 0, "grid_thickness must be less than the inner tray depth");
assert(len(leg_candidates) > 0, "grid too small for legs: reduce leg_foot or grid_thickness");

echo(grid_size = grid_size, leg_height = leg_height, legs = len(leg_positions));

module rounded_rect(size, r) {
    translate([r, r]) offset(r) square([size.x - 2 * r, size.y - 2 * r]);
}

// Box with rounded vertical and bottom edges and a flat top.
module rounded_box(size, r) {
    hull()
        for (x = [r, size.x - r], y = [r, size.y - r])
            translate([x, y, r]) {
                lower_hemisphere(r);
                cylinder(r = r, h = size.z - r);
            }
}

module lower_hemisphere(r) {
    intersection() {
        sphere(r);
        translate([-r, -r, -r]) cube([2 * r, 2 * r, r]);
    }
}

module tray() {
    difference() {
        rounded_box(tray_size, corner_radius);
        // Concentric with the outer rounding, so the wall stays uniform.
        translate([wall, wall, wall])
            rounded_box([cavity_size.x, cavity_size.y, tray_size.z], cavity_radius);
    }
}

module grid_outline_2d() {
    difference() {
        rounded_rect(grid_size, grid_radius);
        for (c = notch_centers) translate(c) circle(r = notch_radius);
    }
}

// The solid part of the grid seen from above: rim and walls between the holes.
module grid_web_2d() {
    difference() {
        grid_outline_2d();
        intersection() {
            offset(delta = -rim_width) grid_outline_2d();
            for (c = hex_centers) translate(c) circle(r = hex_radius, $fn = 6);
        }
    }
}

// Post standing on the floor that flares into the plate, with a fillet as tall
// as the leg. It reaches up through the plate so the two overlap.
module leg_blank() {
    rotate_extrude()
        difference() {
            square([leg_foot + leg_height, grid_size.z]);
            translate([leg_foot + leg_height, 0]) circle(r = leg_height);
        }
}

// In assembled orientation, standing on z = 0. The legs are trimmed to the
// walls, so they are hidden behind the plate when seen from above.
// render() because OpenCSG cannot preview this many concave bodies correctly.
module grid() {
    render() intersection() {
        linear_extrude(grid_size.z) grid_web_2d();
        union() {
            translate([0, 0, leg_height]) cube([grid_size.x, grid_size.y, grid_thickness]);
            for (p = leg_positions) translate(p) leg_blank();
        }
    }
}

// Upside down, plate on the build plate.
module grid_print() {
    translate([0, grid_size.y, grid_size.z]) rotate([180, 0, 0]) grid();
}

// Both parts side by side in print orientation.
module print_plate() {
    color(tray_color) tray();
    color(grid_color) translate([tray_size.x + print_gap, 0, 0]) grid_print();
}

module assembly(lift = 0) {
    color(tray_color) tray();
    color(grid_color)
        translate([wall + clearance, wall + clearance, wall + lift]) grid();
}

// Corner cut through the first leg, showing its fillet and the flush top.
module section() {
    cut_y = wall + clearance + leg_positions[0].y;
    intersection() {
        assembly();
        translate([-1, cut_y, -1]) cube([70, 50, tray_size.z + 2]);
    }
}

if (part == "assembly") assembly();
else if (part == "exploded") assembly(lift = 3 * tray_size.z);
else if (part == "section") section();
else if (part == "tray") color(tray_color) tray();
else if (part == "grid") color(grid_color) grid();
else if (part == "grid_print") color(grid_color) grid_print();
else if (part == "print_plate") print_plate();
else assert(false, str("unknown part: ", part));
