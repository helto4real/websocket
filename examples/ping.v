module main

import websocket
import time

struct TestRef {
pub mut:
	count	int
	sw      time.StopWatch
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

	mut t := TestRef {
		count: 0 
		sw: time.new_stopwatch(auto_start:true)
	
	}
	s.on_message_ref(fn (mut ws websocket.Client, msg &websocket.Message, mut t TestRef)? {
		t.count++
		if t.count >= 1000000 {
			t.sw.stop()
			println('total count: $t.count, elapsed: ${t.sw.elapsed()}')
			ws.close(1000, '') ?
		}
	}, t)

	s.listen() or {println(err)}

	println('total count: $t.count, elapsed: ${t.sw.elapsed()}')
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

	// // use on_message_ref if you want to send any reference object
	// ws.on_message(fn (mut ws websocket.Client, msg &websocket.Message)? {
	// 	println('client got type: $msg.opcode payload:\n$msg.payload')
	// })

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
	b := 'echo this!'.bytes()
	for i:=0; i<1000000 ; i++  {
		// Server will send pings every 30 seconds
		ws.write(b, .text_frame) or {
			panic(err)
		}
		// time.sleep_ms(1000)
	}
}
