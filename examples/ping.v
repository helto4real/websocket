module main

import websocket
import time

struct TestRef {
	count	int
}
fn start_server()? {
	mut s := websocket.new_server(30000, '' ) {
	}
	s.on_connect(fn (mut s &websocket.ServerClient) ?bool {
		// Here you can look att the client info and accept or not accept
		// just returning a true/false
		if s.resource_name != '/' {
			return false
		}
		return true
	})?

	s.on_message(fn (mut ws websocket.Client, msg &websocket.Message)? {
		println('client sent: opcode: $msg.opcode, payload: $msg.payload')
	})
	s.listen()

	println("ENDING SERVER")
}

fn main() {
	go start_server()

	mut ws := websocket.new_client('ws://localhost:30000')?
	// mut ws := websocket.new_client('wss://echo.websocket.org:443')?

	// use on_open_ref if you want to send any reference object
	ws.on_open(fn (mut ws websocket.Client)? {
		println('open!')
	})

	// use on_error_ref if you want to send any reference object
	ws.on_error(fn (mut ws websocket.Client, err string)? {
		println('error: $err')
	})

	// use on_close_ref if you want to send any reference object
	ws.on_close(fn (mut ws websocket.Client, code int, reason string)? {
		println('closed')
	})

	// use on_message_ref if you want to send any reference object
	ws.on_message(fn (mut ws websocket.Client, msg &websocket.Message)? {
		println('client got type: $msg.opcode payload:\n$msg.payload')
	})

	// you can add any pointer reference to use in callback
	// t := TestRef{count: 10}
	// ws.on_message_ref(fn (mut ws websocket.Client, msg &websocket.Message, t &TestRef)? {
	// 	// println('type: $msg.opcode payload:\n$msg.payload ref: $t')
	// }, &t)

	ws.connect()?
	go write_echo(mut ws)
	ws.listen()?
}

fn write_echo(mut ws websocket.Client) {
	for i:=0; ; i++ {
		// Server will send pings every 30 seconds
		ws.write('echo this!'.bytes(), .text_frame) or {
			panic(err)
		}
		time.sleep_ms(1000)
	}
}
