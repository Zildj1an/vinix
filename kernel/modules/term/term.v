// term.v: Terminal stuff.
// Code is governed by the GPL-2.0 license.
// Copyright (C) 2021-2022 The Vinix authors.

module term

import klock
import x86.cpu
import dev.fbdev.api
import dev.fbdev.simple
import limine

__global (
	terminal_tag        = &limine.LimineTerminal(0)
	terminal_print_lock klock.Lock
	terminal_print_ptr  fn(&limine.LimineTerminal, charptr, u64)
	terminal_rows       = u32(0)
	terminal_cols       = u32(0)
	framebuffer_tag     = &limine.LimineFramebuffer(0)
	framebuffer_width   = u16(0)
	framebuffer_height  = u16(0)
)

[cinit]
__global (
	volatile fb_req = limine.LimineFramebufferRequest{response: 0}
)

pub fn initialise() {
	terminal_tag = unsafe { term_req.response.terminals[0] }
	terminal_print_ptr = term_req.response.write
	terminal_rows = terminal_tag.rows
	terminal_cols = terminal_tag.columns

	framebuffer_tag = unsafe { fb_req.response.framebuffers[0] }
	framebuffer_width = framebuffer_tag.width
	framebuffer_height = framebuffer_tag.height
}

pub fn framebuffer_init() {
	sfb_config := simple.SimpleFBConfig {
		physical_address: framebuffer_tag.address,
		width: u32(framebuffer_width),
		height: u32(framebuffer_height),
		stride: u32(framebuffer_tag.pitch),
		bits_per_pixel: u32(framebuffer_tag.bpp),
		red: api.FBBitfield {
			offset: framebuffer_tag.red_mask_shift,
			length: framebuffer_tag.red_mask_size,
			msb_right: 0,
		},
		green: api.FBBitfield {
			offset: framebuffer_tag.green_mask_shift,
			length: framebuffer_tag.green_mask_size,
			msb_right: 0,
		},
		blue: api.FBBitfield {
			offset: framebuffer_tag.blue_mask_shift,
			length: framebuffer_tag.blue_mask_size,
			msb_right: 0,
		},
		transp: api.FBBitfield {
			offset: 0,
			length: 0,
			msb_right: 0,
		},
	}

	simple.register_simple_framebuffer(sfb_config)
}

pub fn print(s voidptr, len u64) {
	current_cr3 := &u64(cpu.read_cr3())
	if vmm_initialised && current_cr3 != kernel_pagemap.top_level {
		kernel_pagemap.switch_to()
	}
	terminal_print_lock.acquire()
	terminal_print_ptr(terminal_tag, s, len)
	terminal_print_lock.release()
	if vmm_initialised && current_cr3 != kernel_pagemap.top_level {
		cpu.write_cr3(u64(current_cr3))
	}
}
