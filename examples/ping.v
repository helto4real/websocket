module main

import websocket
import time

struct TestRef {
	count	int
}
fn main() {
	mut ws := websocket.new_client('wss://echo.websocket.org:443')?

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
		println('type: $msg.opcode payload:\n$msg.payload')
	})

	// you can add any pointer reference to use in callback
	t := TestRef{count: 10}
	ws.on_message_ref(fn (mut ws websocket.Client, msg &websocket.Message, t &TestRef)? {
		println('type: $msg.opcode payload:\n$msg.payload ref: $t')
	}, &t)

	ws.connect()?
	go write_echo(mut ws)
	ws.listen()?
}

fn write_echo(mut ws websocket.Client) {
	for i:=0; ; i++ {
		if i % 5 == 0 {
			ws.ping()
		} else {
			ws.write('hello echo!'.bytes(), .text_frame) or {
				panic(err)
			}
		}
		time.sleep_ms(1000)
	}
}

fn on_echo(mut ws websocket.Client, msg &websocket.Message, t voidptr) ? {
	println('type: $msg.opcode, payload: $msg.payload')
	return none
}
