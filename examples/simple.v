module main

import websocket
import time

fn main() {
	// case_count := http.get('ws://localhost:9001/getCaseCount')
	// println(case_count)
	///runCase?casetuple=1.2.8&agent=my_websocket_client
	// mut ws := websocket.new_client('ws://localhost:9001/runCase?casetuple=1.2.1&agent=my_websocket_client') ?
	// mut ws := websocket.new_client('ws://localhost:8765') ?
	// mut ws := websocket.new_client('wss://echo.websocket.org:443') ?
	// mut ws := websocket.dial('wss://echo.websocket.org:443') ?
	// mut ws := websocket.dial('ws://demos.kaazing.com/echo:80') ?
	// defer { ws.close(1000, "normal close")? }
	
	// time.sleep_ms(100)

	// x := ws.conn.read() ?
	// println(x)
	// ws.write([], .text_frame)
	// ws.close(1000, '')
	// for i in 0..r.len {
	// 	println(int(r[i]))
	// }

	// Get case count
	// mut ws := websocket.new_client('ws://localhost:9001/getCaseCount') ?
	// ws.connect() ?
	// do_work(ws)
	//249
	for i in 240..247 {
		println('\ncase: $i')
		handle_case(i) or {println('error should be ok')}
		// time.sleep_ms(300)
	}


	// uri := 'ws://localhost:9001/runCase?casetuple=1.1.1&agent=v-client'
	// ws := websocket.new_client(uri) ?
	// ws.connect()
	// ws.listen(callback)

	time.sleep_ms(2000)

	// for _ in 0..10 {
	// 	send_msg := 'hello'
	// 	data := send_msg.bytes()
	// 	ws.write(data, .text_frame) or {panic(err)} 
	// 	time.sleep_ms(1000)
	// }

	// ws.close(1000, '') ?
	
	// ws.
}
fn handle_case(case_nr int) ?
{
	uri := 'ws://localhost:9001/runCase?case=$case_nr&agent=v-client'
	ws := websocket.new_client(uri) ?
	ws.connect() ?
	ws.listen(callback) ?

}

fn do_work(ws &websocket.Client) {
	ws.listen(getsize)
}

fn callback(mut ws websocket.Client, msg &websocket.Message) {
	ws.write(msg.payload, msg.opcode) or {panic(err)}
}

fn getsize(mut ws websocket.Client, msg &websocket.Message) {
	println('payload: $msg.payload')
}