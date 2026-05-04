package sdl3_example

import sdl "vendor:sdl3"
import "core:fmt"
import "core:math"

// Available render drivers
@require_results
get_driver_names :: proc() -> (drivers: []cstring, count: i32) {
	count = sdl.GetNumRenderDrivers()
	drivers = make([]cstring, count)
	for d in 0 ..< count {
		drivers[d] = sdl.GetRenderDriver(d)
	}
	return
}

// Return first driver found in priority list or empty cstring
set_driver_by_priority :: proc(priority_list: []cstring) -> (driver: cstring) {
	driver_list, _ := get_driver_names()
	defer delete(driver_list)
	for priority in priority_list {
		for d in driver_list {
			if d == priority {
				return priority
			}
		}
	}
	return
}

// draw something for funs
Triangle :: struct {v0, v1, v2: sdl.FPoint}
sierpinksi :: proc(r: ^sdl.Renderer, t: Triangle, depth: int) {
	if depth == 0 { // draw at depth
		t_raw := [4]sdl.FPoint{t.v0, t.v1, t.v2, t.v0}
		sdl.RenderLines(r, raw_data(t_raw[:]), 4)
	}
	if depth > 0 { // recurse to depth
		sierpinksi(r, {t.v0, (t.v0 + t.v1) / 2, (t.v0 + t.v2) / 2}, depth - 1) // top
		sierpinksi(r, {t.v1, (t.v1 + t.v2) / 2, (t.v0 + t.v1) / 2}, depth - 1) // left
		sierpinksi(r, {t.v2, (t.v0 + t.v2) / 2, (t.v1 + t.v2) / 2}, depth - 1) // right
	}
}

main :: proc() {

	// Not required, but good practice since many applications will use this to display "about" info.
	meta_ok := sdl.SetAppMetadata("Example Renderer", "1.0", "https://forum.odin-lang.org")

	// Initialize SDL
	sdl_ok := sdl.Init({.VIDEO})
	defer sdl.Quit()

	if !meta_ok || !sdl_ok {
		fmt.eprintln("Failed to initialize")
		return
	}

	// set driver based on priority per OS type
	driver: cstring
	when ODIN_OS == .Linux {
		driver = set_driver_by_priority({"vulkan", "gpu", "opengl", "software"})
	} else when ODIN_OS == .Windows {
		driver = set_driver_by_priority({"direct3d12", "direct3d11", "direct3d", "gpu", "opengl", "software"})
	} else when ODIN_OS == .Darwin { // metal supported on macOS 10.14+ and iOS/tvOS 13.0+
		driver = set_driver_by_priority({"metal", "gpu", "opengl", "software"})
	} else {
		driver = set_driver_by_priority({"gpu", "opengl", "software"})
	}

	if driver == nil {
		fmt.eprintfln("%s %v", "Unable to load driver from priority list for", ODIN_OS)
		return
	}

	// note: resizing window repeatedly exposes nvidia bug
	// https://github.com/libsdl-org/SDL/issues/14278
	// check configured limit of file descriptors in os with command line: ulimit -n
	window   := sdl.CreateWindow("Example Renderer", 640, 480, {.RESIZABLE})
	renderer := sdl.CreateRenderer(window, driver)
	sdl.SetRenderLogicalPresentation(renderer, 640, 480, .LETTERBOX)

	defer sdl.DestroyWindow(window)
	defer sdl.DestroyRenderer(renderer)

	// Enable VSync
	vsync_ok := sdl.SetRenderVSync(renderer, 1)
	if !vsync_ok {
		fmt.eprintln("Failed to enable VSync")
	}

	// Some variables for main loop
	display_id      := sdl.GetDisplayForWindow(window)
	display_mode    := sdl.GetCurrentDisplayMode(display_id)
	refresh_rate    := display_mode.refresh_rate
	vsync_enabled   := true
	fps_cap_enabled := true
	fps_target      := 5
	s_depth         := 5
	fps: f64

	color: sdl.FColor
	color_paused: bool

	// some data for printing debug info
	drivers, _ := get_driver_names()
	defer delete(drivers)

	controls := [][]cstring {
		{"Quit",           "Q", "ESC"},
		{"Pause Color",    "P", "LMB"},
		{"Toggle Vsync",   "V", ""},
		{"Toggle FPS Cap", "F", ""},
		{"Triangle Depth", "0", "to 9"},
	}

	// Main loop
	main_loop: for {

		// Get counter before whole frame
		frame_start := sdl.GetTicksNS()

		// Handle events
		for e: sdl.Event; sdl.PollEvent(&e); /**/ {
			#partial switch e.type {
			case .QUIT:
				break main_loop
			case .WINDOW_CLOSE_REQUESTED:
				break main_loop
			case .KEY_UP:
				switch e.key.key {
				case sdl.K_0..=sdl.K_9:
					s_depth = int(e.key.key - 0x00000030)
				case sdl.K_P:
					color_paused = !color_paused
				case sdl.K_ESCAPE:
					break main_loop
				case sdl.K_Q:
					break main_loop
				case sdl.K_V:
					vsync_enabled = !vsync_enabled
					sdl.SetRenderVSync(renderer, vsync_enabled ? 1 : sdl.RENDERER_VSYNC_DISABLED)
				case sdl.K_F:
					fps_cap_enabled = !fps_cap_enabled
				}
			case .MOUSE_BUTTON_UP:
				switch e.button.button {
				case sdl.BUTTON_LEFT:
					color_paused = !color_paused
				}
			}
		}

		// Smoothly change color on each loop if not paused
		if !color_paused {
			now    := f64(frame_start) / 1000000000.000 // convert to seconds
			color.r = f32(0.500 + 0.500 * sdl.sin(now))
			color.g = f32(0.500 + 0.500 * sdl.sin(now + math.PI * 2 / 3))
			color.b = f32(0.500 + 0.500 * sdl.sin(now + math.PI * 4 / 3))
			color.a = sdl.ALPHA_OPAQUE_FLOAT // opaque
		}

		// Set new background color
		sdl.SetRenderDrawColorFloat(renderer, color.r, color.g, color.b, color.a)
		sdl.RenderClear(renderer)

		// Set color compliment of background and draw triangle(s)
		sdl.SetRenderDrawColorFloat(renderer, 1 - color.r, 1 - color.g, 1 - color.b, 255)
		t := Triangle{{366, 20}, {112, 460}, {620, 460}}
		sierpinksi(renderer, t, s_depth)

		// Set font color and some debug text
		r: f32 // mini row iterator
		row :: proc(row: ^f32, height: f32) -> f32 { row^ += height; return row^ }
		sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255)
		sdl.RenderDebugText(renderer, 10, row(&r, 10), "hellope world!")
		sdl.RenderDebugText(renderer, 10, row(&r, 20), fmt.ctprintf("%-16s%v", "Triangle Depth:", s_depth))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%v", "Color Paused:", color_paused))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%v", "VSync Enabled:", vsync_enabled))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%v", "Refresh Rate:", refresh_rate))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%v", "FPS Capped:", fps_cap_enabled))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%i", "FPS Target:", fps_target))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%.2f", "FPS Current:", fps))
		sdl.RenderDebugText(renderer, 10, row(&r, 20), "Found Drivers:")
		for d in drivers {
			sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%s %s", d, d == driver ? "(Loaded)":""))
		}
		sdl.RenderDebugText(renderer, 10, row(&r, 20), "Controls:")
		for c in controls {
			sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%-2s%s", c[0], c[1], c[2]))
		}

		// Free context.temp_allocator from use of fmt.ctprint. This process free's up memory and improves performance!
		free_all(context.temp_allocator)

		// Present renderer
		sdl.RenderPresent(renderer)

		// Get counter after whole frame
		frame_end := sdl.GetTicksNS()

		// Cap fps if enabled
		npf_target := u64(1000000000 / fps_target) // nanoseconds per frame target
		if fps_cap_enabled && (frame_end - frame_start) < npf_target {
			sleep_time := npf_target - (frame_end - frame_start)
			sdl.DelayPrecise(sleep_time)
			frame_end = sdl.GetTicksNS() // Update frame_end counter to include sleep_time for fps calculation
		}

		// update fps tracker
		fps = 1000000000.000 / f64(frame_end - frame_start)
	}
}