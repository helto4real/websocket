module main

import websocket
// import time
fn main() {

	// mut ws := websocket.dial('ws://localhost:8765') ?
	mut ws := websocket.dial('wss://echo.websocket.org:443') ?
	// mut ws := websocket.dial('ws://demos.kaazing.com/echo:80') ?
	// defer { ws.close(1000, "normal close")? }
	// mut ws := websocket.new('ws://localhost:8765')
	// ws.nonce_size = 16
	// ws.connect()
	

	send_msg := 'hello'
	data := send_msg.bytes()
	ws.write(data, .text_frame) or {panic(err)} 
	
	// or {
	// 	println('ops')
	// 	panic(err)
	// 	}// ?
	println("wrote the damn thing") 
	// bytes := msg.str
	// data := voidptr(msg.str)
	// ws.write(data, msg.len, .text_frame) ?// ?
	// ws.read()
	msg := ws.read_next_message() ?
	println(msg)

	// time.sleep_ms(3000)
	ws.close(1000, "normal") ?
	
	// ws.
}