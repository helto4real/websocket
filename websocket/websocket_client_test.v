import websocket
import time

struct Test {
mut:
	connected    bool = false
	sent_messages     []string = []
	received_messages []string = []
}

// Tests with external ws & wss servers
fn test_ws() {
	ws_test('ws://echo.websocket.org')
	ws_test('wss://echo.websocket.org')
}

fn ws_test(uri string) {
	mut test := Test{}
	println('connecting to $uri ...')
	mut ws := websocket.new_client('ws://localhost:30000')?
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
	})
	ws.connect()
	go ws.listen()
	text := ['ws test', '{"vlang": "test0\n192"}']
	for msg in text {
		test.sent_messages << msg
		len := ws.write(msg.str, msg.len, .text_frame)
		assert msg.len <= len
		// sleep to give time to recieve response before send a new one
		time.sleep_ms(100)
	}
	// sleep to give time to recieve response before asserts
	time.sleep_ms(500)

	assert test.connected == true
	assert test.sent_messages.len == test.received_messages.len
	for x, msg in test.sent_messages {
		assert msg == test.received_messages[x]
	}
}

fn on_message(mut test Test, msg &websocket.Message, ws &websocket.Client) {
	typ := msg.opcode
	if typ == .text_frame {
		println('Message: ${cstring_to_vstring(msg.payload)}')
		test.received_messages << cstring_to_vstring(msg.payload)
	} else {
		println('Binary message: $msg')
	}
}

fn on_close(x, y voidptr, ws &websocket.Client) {
	println('websocket closed.')
}

fn on_error(x, y voidptr, ws &websocket.Client) {
	println('we have an error.')
	assert false
}