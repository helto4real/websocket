module main

import websocket

fn main() {
	for i in 1..303 {
		println('\ncase: $i')
		handle_case(i) or {println('error should be ok')}
		// time.sleep_ms(300)
	}
}

fn handle_case(case_nr int) ?
{
	uri := 'ws://localhost:9001/runCase?case=$case_nr&agent=v-client'
	ws := websocket.new_client(uri) ?
	ws.connect() ?
	ws.listen(callback) ?

}

fn callback(mut ws websocket.Client, msg &websocket.Message) {
	ws.write(msg.payload, msg.opcode) or {panic(err)}
}

// fn getsize(mut ws websocket.Client, msg &websocket.Message) {
// 	println('payload: $msg.payload')
// }


	// uri := 'ws://localhost:9001/runCase?casetuple=1.1.1&agent=v-client'
	// ws := websocket.new_client(uri) ?
	// ws.connect()
	// ws.listen(callback)

		// case_count := http.get('ws://localhost:9001/getCaseCount')
	// println(case_count)
	///runCase?casetuple=1.2.8&agent=my_websocket_client
	// mut ws := websocket.new_client('ws://localhost:9001/runCase?casetuple=1.2.1&agent=my_websocket_client') ?
	// mut ws := websocket.new_client('ws://localhost:8765') ?
	// mut ws := websocket.new_client('wss://echo.websocket.org:443') ?
	// mut ws := websocket.dial('wss://echo.websocket.org:443') ?
	// mut ws := websocket.dial('ws://demos.kaazing.com/echo:80') ?