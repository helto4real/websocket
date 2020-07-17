module main


import websocket
import time

fn main() {
	mut ws := websocket.new_client('wss://echo.websocket.org:443') ?
	ws.subscriber.subscribe('on_message', on_echo)
	ws.connect() ?

	go write_echo(mut ws)

	ws.listen() ?	
}

fn write_echo(mut ws websocket.Client) {
	for {
		ws.write('hello echo!'.bytes(), .text_frame) or {panic(err)}
		time.sleep_ms(1000)
	}
}

fn on_echo(mut ws websocket.Client, msg &websocket.Message, t voidptr) ? {
	println('GOT: $msg.payload')
	return none
}
