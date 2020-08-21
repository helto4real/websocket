module main
import websocket

const (
		///
        gateway = 'wss://gateway.discord.gg:443/?encoding=json&v=6'
)

fn main() {
	mut ws := websocket.new_client(gateway)?
	mut d := &Discord{}

	// use on_open_ref if you want to send any reference object
	ws.on_open(fn (mut ws websocket.Client) ? {
		println('open!')
	})
	// use on_error_ref if you want to send any reference object
	ws.on_error(fn (mut ws websocket.Client, err string) ? {
		println('error: $err')
	})
	// use on_close_ref if you want to send any reference object
	ws.on_close(fn (mut ws websocket.Client, code int, reason string) ? {
		println('closed')
	})

	// use on_message if you not need reference sent
	ws.on_message_ref(fn (mut ws websocket.Client, msg &websocket.Message, r &Discord) ? {

	    println('on message')
        println(msg)
        match msg.opcode {
         	.text_frame {
                println('T')
            }
            else{}
		}
	}, &d)

	ws.connect() or {
		println('error on connect: $err')
	}
	
	ws.listen() or {
		println('error on listen $err')
	}
}
struct Discord {}


