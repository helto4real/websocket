// use this test to test the websocket client in the autobahn test

module main

import websocket

fn main() {
	for i in 1 .. 303 {
		println('\ncase: $i')
		handle_case(i) or {
			println('error should be ok: $err')
		}
	}
}

fn handle_case(case_nr int) ? {
	uri := 'ws://localhost:9001/runCase?case=$case_nr&agent=v-client'
	mut ws := websocket.new_client(uri)?
	ws.on_message(on_message)
	ws.connect()?
	ws.listen()?
}

fn on_message(mut ws websocket.Client, msg &websocket.Message)?  {
	// autobahn tests expects to send same message back
	if msg.opcode == .pong {
		// We just wanna pass text and binary message back to autobahn
		return none
	}
	ws.write(msg.payload, msg.opcode) or {
		panic(err)
	}
}
