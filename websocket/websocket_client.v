// The module websocket implements the websocket capabilities
// it is a refactor of the original V-websocket client class
// from @thecoderr 

module websocket

import emily33901.net
import net.urllib
import time
import log
import sync
import rand

const (
	invalid_close_codes = [999, 1004, 1005, 1006, 1014, 1015, 1016, 1100, 2000, 2999, 5000, 65536]
)

// Client represents websocket client state
pub struct Client {
	is_server		  bool = false
mut:
	mtx               &sync.Mutex = sync.new_mutex()
	write_lock        &sync.Mutex = sync.new_mutex()
	sslctx            &C.SSL_CTX
	ssl               &C.SSL
	flags             []Flag
	fragments         []Fragment
	logger            &log.Log
	message_callbacks []MessageEventHandler
	error_callbacks	  []ErrorEventHandler
	open_callbacks	  []OpenEventHandler
	close_callbacks	  []CloseEventHandler
pub:
	is_ssl            bool
	uri               Uri
	id 				  string
pub mut:
	conn              net.TcpConn
	nonce_size        int = 16 // you can try 18 too
	panic_on_callback bool = false
	state             State
	resource_name	  string
	last_pong_ut	  u64 
}

enum Flag {
	has_accept
	has_connection
	has_upgrade
}

// State of the websocket connection.
// Messages should be sent only on state .open
enum State {
	connecting = 0
	open
	closing
	closed
}

// Message, represents a whole message conbined from 1 to n frames
pub struct Message {
pub:
	opcode  OPCode
	payload []byte
}

// OPCode, the supported websocket frame types
pub enum OPCode {
	continuation = 0x00
	text_frame = 0x01
	binary_frame = 0x02
	close = 0x08
	ping = 0x09
	pong = 0x0A
}

// new_client, instance a new websocket client
pub fn new_client(address string)? &Client {
	uri := parse_uri(address)?
	return &Client{
		is_server: false
		sslctx: 0
		ssl: 0
		is_ssl: address.starts_with('wss')
		logger: &log.Log{level: .info}
		uri: uri
		state: .closed
		id: rand.uuid_v4()
	}
}

// connect, connects and do handshake procedure with remote server
pub fn (mut ws Client) connect()? {
	ws.assert_not_connected()
	ws.set_state(.connecting)
	ws.logger.info('connecting to host $ws.uri')

	ws.conn = ws.dial_socket()?
	ws.handshake()?
	ws.set_state(.open)
	ws.logger.info('successfully connected to host $ws.uri')

	ws.send_open_event()
}

// listen, listens to incoming messages and handles them
pub fn (mut ws Client) listen()? {
	ws.logger.info('Starting client listener, server($ws.is_server)...')
	defer {
		ws.logger.info('Quit client listener, server($ws.is_server)...')
	}
	for ws.state == .open {
		msg := ws.read_next_message() or {
			if ws.state in [.closed] {
				return
			}
			ws.debug_log('failed to read next message: $err')
			return error(err)
		}
		ws.debug_log('got message: $msg.opcode, payload: $msg.payload')
		match msg.opcode {
			.text_frame {
				ws.debug_log('read: text')
				ws.send_message_event(mut msg)
			}
			.binary_frame {
				ws.debug_log('read: binary')
				ws.send_message_event(mut msg)
			}
			.ping {
				ws.debug_log('read: ping, sending pong')
				ws.send_control_frame(.pong, 'PONG', msg.payload) or {
					ws.logger.error('error in message callback sending PONG: $err')
					if ws.panic_on_callback {
						panic(err)
					}
					continue
				}
			}
			.pong {
				ws.debug_log('read: pong')
				ws.last_pong_ut = time.now().unix
				ws.send_message_event(mut msg)
			}
			.close {
				ws.debug_log('read: close')
				defer {
					ws.manage_clean_close()
				}
				if msg.payload.len > 0 {
					if msg.payload.len == 1 {
						ws.close(1002, 'close payload cannot be 1 byte')?
						return error('close payload cannot be 1 byte')
					}
					code := (int(msg.payload[0]) << 8) + int(msg.payload[1])
					if code in invalid_close_codes {
						ws.close(1002, 'invalid close code: $code')?
						return error('invalid close code: $code')
					}
					reason := if msg.payload.len > 2 { msg.payload[2..] } else { []byte{} }
					if reason.len > 0 {
						ws.validate_utf_8(.close, reason)?
					}
					if ws.state !in [.closing, .closed] {
						// sending close back according to spec
						ws.debug_log('close with reason, code: $code, reason: $reason')
						r := if reason.len > 0 {string(reason)} else {''}
						ws.close(code, r)?
					}
				} else {
					if ws.state !in [.closing, .closed] {
						ws.debug_log('close with reason, no code')
						// sending close back according to spec
						ws.close(1000, 'normal')?
					}
				}
				return
			}
			.continuation {
				ws.logger.error('unexpected opcode continuation, nothing to continue')
				ws.close(1002, 'nothing to continue')?
				return error('unexpected opcode continuation, nothing to continue')
			}
		}
	}
}

// this function was needed for defer
fn (mut ws Client) manage_clean_close() {
	ws.send_close_event(1000, 'closed by client')
}

// ping, sends ping message to server, 
// 		 ping response will be pushed to message callback
pub fn (mut ws Client) ping() ? {
	ws.send_control_frame(.ping, 'PING', []) ?
}

// pong, sends pog message to server, 
// 		 pongs are normally automatically sent back to server
pub fn (mut ws Client) pong() ? {
	ws.send_control_frame(.pong, 'PONG', []) ?
}

// write, writes a byte array with a websocket messagetype
pub fn (mut ws Client) write(bytes []byte, code OPCode) ? {
	ws.debug_log('write code: $code, payload: $bytes')
	if ws.state != .open || ws.conn.sock.handle < 1 {
		// send error here later
		return error('trying to write on a closed socket!')
	}
	payload_len := bytes.len
	mut header_len := 2 + if payload_len > 125 { 2 } else { 0 } + if payload_len > 0xffff { 6 } else { 0 }
	if !ws.is_server {
		header_len += 4
	}
	
	mut header := [`0`].repeat(header_len)
	header[0] = byte(code) | 0x80
	mut masking_key := []byte{}
	defer {
		unsafe {
			free(payload_len)
			free(masking_key)
			free(header)
		}
	}
	if ws.is_server {
		if payload_len <= 125 {
			header[1] = byte(payload_len ) //| 0x80
		} else if payload_len > 125 && payload_len <= 0xffff {
			len16 := C.htons(payload_len)
			header[1] = (126 ) //| 0x80
			// todo: fix v style copy instead
			unsafe {
				C.memcpy(header.data + 2, &len16, 2)
			}
		} else if payload_len > 0xffff && payload_len <= 0xffffffffffffffff {
			len64 := htonl64(u64(payload_len))
			header[1] = (127) // 0x80
			// todo: fix v style copy instead
			unsafe {
				C.memcpy(header.data + 2, len64.data, 8)
			}
		}
	} else {
		masking_key = create_masking_key()
		if payload_len <= 125 {
			header[1] = byte(payload_len | 0x80)
			header[2] = masking_key[0]
			header[3] = masking_key[1]
			header[4] = masking_key[2]
			header[5] = masking_key[3]
		} else if payload_len > 125 && payload_len <= 0xffff {
			len16 := C.htons(payload_len)
			header[1] = (126 | 0x80)
			// todo: fix v style copy instead
			unsafe {
				C.memcpy(header.data + 2, &len16, 2)
			}
			header[4] = masking_key[0]
			header[5] = masking_key[1]
			header[6] = masking_key[2]
			header[7] = masking_key[3]
		} else if payload_len > 0xffff && payload_len <= 0xffffffffffffffff { // 65535 && 18446744073709551615
			len64 := htonl64(u64(payload_len))
			header[1] = (127 | 0x80)
			// todo: fix v style copy instead
			unsafe {
				C.memcpy(header.data + 2, len64.data, 8)
			}
			header[10] = masking_key[0]
			header[11] = masking_key[1]
			header[12] = masking_key[2]
			header[13] = masking_key[3]
		} else {
			// l.c('write: frame too large')
			ws.close(1009, 'frame too large')?
			return error('frame too large')
		}
		unsafe {
			free(masking_key)
		}
	}
	mut frame_buf := []byte{}
	frame_buf << header
	frame_buf << bytes

	if !ws.is_server {
		for i in 0 .. payload_len {
			frame_buf[header_len + i] ^= masking_key[i % 4] & 0xff
		}
	}
	ws.socket_write(frame_buf)?
}

// close, closes the websocket connection 
pub fn (mut ws Client) close(code int, message string) ? {
	ws.debug_log('sending close, $code, $message')
	if ws.state in [.closed, .closing] || ws.conn.sock.handle <= 1 {
		ws.debug_log('close: Websocket allready closed ($ws.state), $message, $code handle($ws.conn.sock.handle)')
		return error('Socket allready closed: $code')
	}
	defer {
		ws.shutdown_socket()
	}
	defer {
		ws.reset_state()
	}
	ws.set_state(.closing)
	mut code32 := 0
	if code > 0 {
		code_ := C.htons(code)
		message_len := message.len + 2
		mut close_frame := [`0`].repeat(message_len)
		close_frame[0] = byte(code_ & 0xFF)
		close_frame[1] = byte(code_ >> 8)
		code32 = (close_frame[0] << 8) + close_frame[1]
		for i in 0 .. message.len {
			close_frame[i + 2] = message[i]
		}
		ws.send_control_frame(.close, 'CLOSE', close_frame)?
		ws.send_close_event(code, message)
	} else {
		ws.send_control_frame(.close, 'CLOSE', [])?
		ws.send_close_event(code, '')
	}
	ws.fragments = []
}

// send_control_frame, sends a control frame to the server
fn (mut ws Client) send_control_frame(code OPCode, frame_typ string, payload []byte) ? {
	ws.debug_log('send control frame $code, frame_type: $frame_typ, payload: $payload')
	if ws.state !in [.open, .closing] && ws.conn.sock.handle > 1 {
		return error('socket is not connected')
	}
	header_len := if ws.is_server {2} else {6}
	frame_len := header_len + payload.len
	mut control_frame := [`0`].repeat(frame_len)
	mut masking_key := []byte{}

	control_frame[0] = byte(code | 0x80)
	if !ws.is_server {
		masking_key = create_masking_key()
		control_frame[1] = byte(payload.len | 0x80)
		control_frame[2] = masking_key[0]
		control_frame[3] = masking_key[1]
		control_frame[4] = masking_key[2]
		control_frame[5] = masking_key[3]

	} else {
		control_frame[1] = byte(payload.len)
	}
	if code == .close {
		if payload.len >= 2 {
			
			if !ws.is_server {
				mut parsed_payload := [`0`].repeat(payload.len + 1)
				unsafe {
					C.memcpy(parsed_payload.data, &payload[0], payload.len)
				}
				parsed_payload[payload.len] = `\0`
				for i in 0 .. payload.len {
					control_frame[6 + i] = (parsed_payload[i] ^ masking_key[i % 4]) & 0xff
				}
			} else {
				unsafe {
					C.memcpy(control_frame.data+2, &payload[0], payload.len)
				}	
			}
		}
	} else {
		if !ws.is_server {
			for i in 0 .. payload.len {
				control_frame[header_len + i] = (payload[i] ^ masking_key[i % 4]) & 0xff
			}
		} else {
			if payload.len > 0 {
				unsafe {
						C.memcpy(&control_frame[2], &payload[0], payload.len)
				}
			}
		}
	}
	ws.socket_write(control_frame) or {
		return error('send_control_frame: error sending $frame_typ control frame.')
	}
}

// parse_uri, parses the url string to it's components
// todo: support not using port to default ones
fn parse_uri(url string)? &Uri {
	u := urllib.parse(url) or {
		return error(err)
	}
	v := u.request_uri().split('?')
	querystring := if v.len > 1 { '?' + v[1] } else { '' }
	return &Uri{
		url: url
		hostname: u.hostname()
		port: u.port()
		resource: v[0]
		querystring: querystring
	}
}

[inline]
// set_state sets current state in a thread safe way
fn (mut ws Client) set_state(state State) {
	ws.mtx.m_lock()
	ws.state = state
	ws.mtx.unlock()
}

[inline]
fn (ws Client) assert_not_connected()? {
	match ws.state {
		.connecting { return error('connect: websocket is connecting') }
		.open { return error('connect: websocket already open') }
		else {}
	}
}

[inline]
// reset_state, resets the websocket and can connect again
fn (mut ws Client) reset_state() {
	ws.mtx.m_lock()
	ws.state = .closed
	ws.sslctx = 0
	ws.ssl = 0
	ws.flags = []
	ws.fragments = []
	ws.mtx.unlock()
}

fn (mut ws Client) debug_log(text string) {
	if ws.is_server {
		ws.logger.debug('server-> $text')
	} else {
		ws.logger.debug('client-> $text')
	}
}