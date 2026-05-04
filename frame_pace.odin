package main
import sdl "vendor:sdl3"

import "core:fmt"
//Artificially clamps the FPS
frame_pace :: proc(npf_target:u64, frame_start:sdl.Uint64, frame_end:^sdl.Uint64)
{
	sleep_time := npf_target - (frame_end^ - frame_start)
	sdl.DelayPrecise(sleep_time)
	frame_end^ = sdl.GetTicksNS() // Update frame_end counter to include sleep_time for fps calculation
}