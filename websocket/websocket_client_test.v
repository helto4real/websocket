import websocket
import time

// Tests with external ws & wss servers
fn test_ws()? {
	ws_test('ws://echo.websocket.org')?
	ws_test('wss://echo.websocket.org')?
}

fn ws_test(uri string)? {
	println('connecting to $uri ...')
	mut ws := websocket.new_client(uri)?
	ws.on_open(fn (mut ws websocket.Client) ? {
		println('open!')
		ws.pong()
		assert true
	})
	ws.on_error(fn (mut ws websocket.Client, err string) ? {
		println('error: $err')
		// this can be thrown by internet connection problems
		assert false
	})
	ws.on_close(fn (mut ws websocket.Client, code int, reason string) ? {
		println('closed')
	})
	ws.on_message(fn (mut ws websocket.Client, msg &websocket.Message) ? {
		println('client got type: $msg.opcode payload:\n$msg.payload')
		if msg.opcode == .text_frame {
			println('Message: ${string(msg.payload, msg.payload.len)}')
			assert string(msg.payload, msg.payload.len) == 'a'
		} else {
			println('Binary message: $msg')
		}
	})
	ws.connect()
	go ws.listen()
	text := ['a'].repeat(2)
	for msg in text {
		ws.write(msg.bytes(), .text_frame)?
		// sleep to give time to recieve response before send a new one
		time.sleep_ms(100)
	}
	// sleep to give time to recieve response before asserts
	time.sleep_ms(500)
}