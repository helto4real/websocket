module main

import websocket
import time

fn main() {
	// mut ws := websocket.new_client('wss://echo.websocket.org:443')?
	mut ws := websocket.new_client('ws://localhost:8765')?

	ws.on_open(fn (mut ws websocket.Client)? {
		println('open!')
	})

	ws.on_error(fn (mut ws websocket.Client, err string)? {
		println('error: $err')
	})

	ws.on_close(fn (mut ws websocket.Client, code int, reason string)? {
		println('closed')
	})

	ws.on_message(fn (mut ws websocket.Client, msg &websocket.Message)? {
		println('type: $msg.opcode payload:\n$msg.payload')
	})

	
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
