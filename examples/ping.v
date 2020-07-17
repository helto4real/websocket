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
	mut i := 1
	for {
		if i%5 == 0 {
			ws.ping()
		} else {
			ws.write('hello echo!'.bytes(), .text_frame) or {panic(err)}
		}
		time.sleep_ms(1000)
		i++
	}
}

fn on_echo(mut ws websocket.Client, msg &websocket.Message, t voidptr) ? {
	println('type: $msg.opcode, payload: $msg.payload')
	return none
}
