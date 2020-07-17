module main

import websocket
import time

fn main() {
	// //303
	// for i in 1..5 {
	// 	println('\ncase: $i')
	// 	handle_case(i) or {println('error should be ok: $err')}
	// 	// time.sleep_ms(300)
	// }

	try_ping()
}

fn handle_case(case_nr int) ?
{
	uri := 'ws://localhost:9001/runCase?case=$case_nr&agent=v-client'
	mut ws := websocket.new_client(uri) ?
	ws.subscriber.subscribe('on_message', on_message)
	ws.connect() ?
	ws.listen() ?

}


fn on_message(mut ws websocket.Client, msg &websocket.Message, t voidptr) {
	ws.write(msg.payload, msg.opcode) or {panic(err)}
}
