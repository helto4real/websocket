module websocket
import encoding.base64

// handshake manage the handshake part of connecting
fn (mut c Client) handshake(uri Uri) ? {

	nonce := get_nonce(16)
	seckey := base64.encode(nonce)

	handshake := 'GET ${uri.resource}${uri.querystring} HTTP/1.1\r\nHost: ${uri.hostname}:${uri.port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: ${seckey}\r\nSec-WebSocket-Version: 13\r\n\r\n'

	handshake_bytes := handshake.bytes()

	c.socket_write(handshake_bytes) ?
	c.read_handshake(seckey)

}

fn (mut ws Client) read_handshake(seckey string) ? {
	mut bytes_read := 0
	max_buffer := 1024

	mut msg := []byte{}
	for bytes_read <= max_buffer {
		mut buffer := []byte{len: max_buffer, init: 0}
		bytes_read = ws.socket_read_into(mut buffer) ?
		println('READBYTES: $bytes_read')
		println('BUFFER: $buffer')
		msg << buffer[..bytes_read]
		if buffer[bytes_read-1] == `\n` && buffer[bytes_read - 2] == `\r` && buffer[bytes_read -
			3] == `\n` && buffer[bytes_read - 4] == `\r` {
			break
		}
	}

	// println('READ LEFT?: $b_read, $buf')
	ws.handshake_handler(string(msg), seckey)
}

fn (mut ws Client) handshake_handler(handshake_response string, seckey string) ? {
	println('response:\n $handshake_response')
	// l.d('handshake_handler:\r\n${handshake_response}')
	lines := handshake_response.split_into_lines()
	header := lines[0]

	if !header.starts_with('HTTP/1.1 101') && !header.starts_with('HTTP/1.0 101') {
		return error('handshake_handler: invalid HTTP status response code')
	}
	for i in 1 .. lines.len {
		if lines[i].len <= 0 || lines[i] == '\r\n' {
			continue
		}
		keys := lines[i].split(':')
		match keys[0] {
			'Upgrade', 'upgrade' {
				ws.flags << .has_upgrade
			}
			'Connection', 'connection' {
				ws.flags << .has_connection
			}
			'Sec-WebSocket-Accept', 'sec-websocket-accept' {
				// l.d('comparing hashes')
				// l.d('seckey: ${seckey}')
				challenge := create_key_challenge_response(seckey)
				// l.d('challenge: ${challenge}')
				// l.d('response: ${keys[1]}')
				if keys[1].trim_space() != challenge {
					return error('handshake_handler: Sec-WebSocket-Accept header does not match computed sha1/base64 response.')
				}
				ws.flags << .has_accept
			}
			else {}
		}

	}
	if ws.flags.len < 3 {

		// TODO: Do close logic!
		ws.close(1002, 'invalid websocket HTTP headers')
		// l.e('invalid websocket HTTP headers')
		return error('invalid websocket HTTP headers')
	}
	println('handshake successful!')

}
