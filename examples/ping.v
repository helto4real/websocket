module main

import time
import os
import websocket

fn main() {
	go start_server()
	time.sleep_ms(100)
	go start_client()
	// go start_client_disconnect()
	println('press enter to quit...')
	os.get_line()
}

fn start_server() ? {
	mut s := websocket.new_server(30000, '')
	// Make that in execution test time give time to execute at least one time
	s.ping_interval = 100
	s.on_connect(fn (mut s websocket.ServerClient) ?bool {
		// Here you can look att the client info and accept or not accept
		// just returning a true/false
		if s.resource_name != '/' {
			return false
		}
		return true
	})?
	s.on_message(fn (mut ws websocket.Client, msg &websocket.Message) ? {
		// payload := if msg.payload.len == 0 { '' } else { string(msg.payload, msg.payload.len) }
		// println('server client ($ws.id) got message: opcode: $msg.opcode, payload: $payload')
		ws.write(msg.payload, msg.opcode) or {
			panic(err)
		}
	})
	s.on_close(fn (mut ws websocket.Client, code int, reason string) ? {
		// println('client ($ws.id) closed connection')
	})
	s.listen() or {
		// println('error on server listen: $err')
	}
}

fn start_client() ? {
	mut ws := websocket.new_client('ws://localhost:30000')?
	// mut ws := websocket.new_client('wss://echo.websocket.org:443')?
	// use on_open_ref if you want to send any reference object
	ws.on_open(fn (mut ws websocket.Client) ? {
		println('open!')
	})
	// use on_error_ref if you want to send any reference object
	ws.on_error(fn (mut ws websocket.Client, err string) ? {
		println('error: $err')
	})
	// use on_close_ref if you want to send any reference object
	ws.on_close(fn (mut ws websocket.Client, code int, reason string) ? {
		println('closed')
	})
	// use on_message_ref if you want to send any reference object
	ws.on_message(fn (mut ws websocket.Client, msg &websocket.Message) ? {
		payload := if msg.payload.len == 0 { '' } else { string(msg.payload, msg.payload.len) }
		println('client got type: $msg.opcode payload:\n$payload')
	})
	// you can add any pointer reference to use in callback
	// t := TestRef{count: 10}
	// ws.on_message_ref(fn (mut ws websocket.Client, msg &websocket.Message, r &SomeRef)? {
	// // println('type: $msg.opcode payload:\n$msg.payload ref: $r')
	// }, &r)
	ws.connect() or {
		println('error on connect: $err')
	}
	go write_echo(mut ws) or {
		println('error on write_echo $err')
	}
	ws.listen() or {
		println('error on listen $err')
	}
}

fn start_client_disconnect() ? {
	mut ws := websocket.new_client('ws://localhost:30000')?
	// mut ws := websocket.new_client('wss://echo.websocket.org:443')?
	// use on_open_ref if you want to send any reference object
	ws.on_open(fn (mut ws websocket.Client) ? {
		println('open!')
	})
	// use on_error_ref if you want to send any reference object
	ws.on_error(fn (mut ws websocket.Client, err string) ? {
		println('error: $err')
	})
	// use on_close_ref if you want to send any reference object
	ws.on_close(fn (mut ws websocket.Client, code int, reason string) ? {
		println('closed')
	})
	// use on_message_ref if you want to send any reference object
	ws.on_message(fn (mut ws websocket.Client, msg &websocket.Message) ? {
		println('client got type: $msg.opcode payload:\n$msg.payload')
		ws.close(1000, 'close')
	})
	// you can add any pointer reference to use in callback
	// t := TestRef{count: 10}
	// ws.on_message_ref(fn (mut ws websocket.Client, msg &websocket.Message, r &SomeRef)? {
	// // println('type: $msg.opcode payload:\n$msg.payload ref: $r')
	// }, &r)
	ws.connect() or {
		println('error on connect: $err')
	}
	go write_echo(mut ws) or {
		println('error on write_echo $err')
	}
	ws.listen() or {
		println('error on listen $err')
	}
}

fn write_echo(mut ws websocket.Client) ? {
	for i := 0; i <= 1000; i++ {
		// Server will send pings every 30 seconds
		text := 'echo this!'.bytes()
		ws.write(text, .text_frame) or {
			println('panicing writing $err')
		}
		unsafe {
			text.free()
		}
		time.sleep_ms(10)
	}
	println('DONE')
	/*
	ws.close(1000, "normal") or {
		println('panicing $err')
	}
	*/
}
