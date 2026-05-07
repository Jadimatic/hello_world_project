package main

import sdl "vendor:sdl3"
import "vendor:sdl3/image" //This enables rendering of JPEG or PNG files
import "vendor:vulkan"
import "core:math" //A library of useful math functions
import "core:os"
import "core:fmt"
import "core:time"

//To run the application in the terminal, use [odin run .], or replace the "." with the project folder path if it's not already targeted.
//To build the application, use [odin build .] in the terminal, again inserting the path if not already targeted.

render :: proc()
{
	//We think this is where we put the stuff that will be rendered, but keep the stuff that needs to be in certain spots with everything else.
}

application :: proc()
{
	//Stuff would be moved from "main" to here
	testdirectory, ok := os.get_working_directory(context.allocator)
}

init :: proc()
{
	//Initialize non-rendering related things here.
	fmt.println("Hellope!")
	fmt.println(add(2, 3))
	fmt.println(len("This is a test, with a string length of 43."))
}

window : ^sdl.Window
gpu : ^sdl.GPUDevice
sdl_init :: proc() -> bool {
	// Not required, but good practice since many applications will use this to display "about" info.
	sdl_ok := sdl.SetAppMetadata("Example Renderer", "1.0", "Website would go here")
    if !sdl_ok do return false

    sdl_ok = sdl.Init({.VIDEO})
    if !sdl_ok do return false

	window = sdl.CreateWindow("Hello World", 640, 480, {.RESIZABLE}); assert(window != nil)
	sdl.SetWindowMinimumSize(window, 1150, 480)
	when ODIN_OS == .Windows || ODIN_OS == .Linux {
    gpu = sdl.CreateGPUDevice({.SPIRV}, false, nil); assert(gpu != nil)
	} else when ODIN_OS == .Darwin {
		gpu := sdl.CreateGPUDevice({.MSL, .METALLIB}, false, nil); assert(gpu != nil)
	} else {
		gpu := sdl.CreateGPUDevice({.SPIRV, .DXBC, .DXIL, .MSL, .METALLIB}, false, nil); assert(gpu != nil)
	}
	sdl_ok = sdl.ClaimWindowForGPUDevice(gpu, window); assert(sdl_ok) //Assigns the GPU device to a Window.
	sdl_ok = sdl.SetGPUSwapchainParameters(gpu, window, .SDR, .VSYNC); assert(sdl_ok) //Enables VSync.

    return true
}

tick :: proc(deltaTime : time.Duration)
{
	//Put physics processes and anything that needs to run at a constant rate here.
}

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

// Select driver based on priority per OS type
select_driver_per_os :: proc() -> cstring
{
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
		return ""
	}
	return driver
}

main :: proc() {
	sdl_ok : bool = sdl_init()
	driver: cstring = select_driver_per_os()
	window_resizing : bool = false
	init()

	//Some data for printing debug info
	drivers, _ := get_driver_names()

	//Defer processes for deletion
	defer delete(drivers)
	defer sdl.DestroyWindow(window)
	defer sdl.DestroyGPUDevice(gpu)

	// Some variables for main loop
	display_id      := sdl.GetDisplayForWindow(window)
	display_mode    := sdl.GetCurrentDisplayMode(display_id)
	refresh_rate    := display_mode.refresh_rate
	vsync_enabled   := true
	fps_cap_enabled := true
	fps_target      := 60
	s_depth         := 5
	fps: f64

	

	controls := [][]cstring {
		{"Quit",           "ESC", ""},
		{"Toggle Vsync",   "V", ""},
	}


	deltaTime::0.01 * 1e9 //Creates deltaTime for use in procedures.
   	current_time := time.tick_now() //Grabs the current time for use in defining deltaTime.
   	accumulator : time.Duration

	// Main loop
	main_loop: for {
		
		//Defines deltaTime
		new_time:= time.tick_now()
      	frame_time:= time.tick_diff(current_time,new_time)
      	current_time=new_time

      	for accumulator += frame_time;accumulator>= deltaTime; accumulator-= deltaTime {
        	tick(deltaTime)
      	}

		// Get counter before whole frame
		frame_start := sdl.GetTicksNS()
		window_resizing = false

		// Handle events
		for e: sdl.Event; sdl.PollEvent(&e);{
			#partial switch e.type {
			case .QUIT:
				break main_loop
			case .WINDOW_CLOSE_REQUESTED:
				break main_loop
			case .WINDOW_RESIZED:
				window_resizing = true
			case .KEY_UP:
				switch e.key.key {
				case sdl.K_ESCAPE:
					break main_loop
				case sdl.K_Q:
					//empty
				case sdl.K_V: //Do not use outside of debugging!
					vsync_enabled = !vsync_enabled //Flip the bool
					sdl_ok = sdl.SetGPUSwapchainParameters(gpu, window, .SDR,  vsync_enabled ? .VSYNC : .IMMEDIATE); assert(sdl_ok)
					fmt.printfln("{}", vsync_enabled)
					//sdl.SetRenderVSync(renderer, vsync_enabled ? 1 : sdl.RENDERER_VSYNC_DISABLED)
				}
			case .MOUSE_BUTTON_UP:
				switch e.button.button {
				case sdl.BUTTON_LEFT:
					//empty
				case sdl.BUTTON_RIGHT:
					//empty
				}
			}
		}

		if(!window_resizing)
		{
			render()
			//Render code.
			cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)
			swapchain_tex: ^sdl.GPUTexture
			sdl_ok = sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buf, window, &swapchain_tex, nil, nil); assert(sdl_ok)
			color_target := sdl.GPUColorTargetInfo{
				texture = swapchain_tex,
				load_op = .CLEAR,
				clear_color = {0.03, 0.01, 0.007, 255}, //Divide hex values by 255 to get the float values needed here.
				//clear_color = {1.0, 0.71, 0.77, 255}, //Pink
				store_op = .STORE
			}
			render_pass := sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, nil)


			//Draw stuff
			//Figure out how to render debug text here


			//End the renderpass
			sdl.EndGPURenderPass(render_pass)

			sdl_ok = sdl.SubmitGPUCommandBuffer(cmd_buf); assert(sdl_ok) //Submits the final render to be displayed.
		}


		
	


		//Currently obsolete rendering code, keeping for now encase it becomes useful

		/*
		// Draw new colored frame
		//sdl.SetRenderDrawColor(renderer, 0x08, 0x04, 0x02, 255)
		sdl.SetRenderDrawColor(renderer, 0xff, 0xb7, 0xc5, 255)
		sdl.RenderClear(renderer)

		//Draw Sprite Cranberry
		texture_source_rect := sdl.FRect{0, 0, 1500, 1500}
		destination_rect := sdl.FRect{225, 225, 245, 245}
		sdl.RenderTexture(renderer,sprite_cranberry, &texture_source_rect, &destination_rect)

		// Set font color and some debug text
		r: f32 // mini row iterator
		row :: proc(row: ^f32, height: f32) -> f32 { row^ += height; return row^ }
		sdl.SetRenderDrawColor(renderer, 0xdd, 0xdb, 0xd0, 255)
		sdl.RenderDebugText(renderer, 10, row(&r, 10), "hellope world!")
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%v", "VSync Enabled:", vsync_enabled))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%v", "Refresh Rate:", refresh_rate))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%i", "Clamped FPS Target:", fps_target))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%.2f", "Current FPS:", fps))
		sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%q", "Path:", testdirectory))
		sdl.RenderDebugText(renderer, 10, row(&r, 20), "Found Drivers:")
		for d in drivers {
			sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%s %s", d, d == driver ? "(Loaded)":""))
		}
		sdl.RenderDebugText(renderer, 10, row(&r, 20), "Controls:")
		for c in controls {
			sdl.RenderDebugText(renderer, 10, row(&r, 10), fmt.ctprintf("%-16s%-2s%s", c[0], c[1], c[2]))
		}
		*/

		// Free context.temp_allocator from use of fmt.ctprint. This prevents some memory leaks!
		free_all(context.temp_allocator)


		// Get counter after whole frame
		frame_end := sdl.GetTicksNS()

		/*npf_target := u64(1000000000 / fps_target) // nanoseconds per frame target
		if (frame_end - frame_start) < npf_target {frame_pace(npf_target, frame_start, &frame_end)}*/

		// Update fps tracker
		fps = 1000000000.000 / f64(frame_end - frame_start)
	}
}