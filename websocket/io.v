module websocket

import emily33901.net
import time

interface WebsocketIO {
	socket_read_into(mut buffer []byte) ?int
	socket_write(bytes []byte) ?
}

// socket_read_into reads into the provided buffer with it's lenght
fn (mut ws Client) socket_read_into(mut buffer []byte) ?int {
	if ws.is_ssl {
		res := C.SSL_read(ws.ssl, buffer.data, buffer.len)
		if res >= 0 {
			return res
		}
		code := error_code()
		match code {
			error_ewouldblock {
				ws.conn.wait_for_read()?
				return socket_error(C.SSL_read(ws.ssl, buffer.data, buffer.len))
			}
			else {
				wrap_error(code)?
			}
		}
	} else {
		r := ws.conn.read_into(mut buffer)?
		return r
	}
}

// socket_write, writes the whole byte array provided to the socket
fn (mut ws Client) socket_write(bytes []byte) ? {
	defer {
		unsafe {
			free(bytes)
		}
	}
	if ws.state == .closed || ws.conn.sock.handle <= 1 {
		ws.debug_log('write: Socket allready closed')
		return error('Socket allready closed')
	}
	ws.write_lock.m_lock()
	defer {
		ws.write_lock.unlock()
	}
	if ws.is_ssl {
		mut ptr_base := byteptr(bytes.data)
		mut total_sent := 0
		for total_sent < bytes.len {
			ptr := unsafe{ptr_base + total_sent}
			remaining := bytes.len - total_sent
			mut sent := C.SSL_write(ws.ssl, ptr, remaining)
			unsafe {
				free(ptr)
				free(remaining)
			}
			if sent < 0 {
				code := error_code()
				match code {
					error_ewouldblock {
						ws.conn.wait_for_write()
						continue
					}
					else {
						wrap_error(code)?
					}
				}
			}
			total_sent += sent
		}
		unsafe {
			free(ptr_base)
		}
	} else {
		ws.conn.write(bytes)?
	}
}

// shutdown_socket, proper shutdown make PR in Emeliy repo
fn (mut ws Client) shutdown_socket()? {
	ws.debug_log('shutting down socket')
	if ws.ssl != 0 {
		ws.shutdown_ssl()
	} else {
		ws.conn.close()?
	}
}

// dial_socket, setup socket communication, options and timeouts
fn (mut ws Client) dial_socket()? net.TcpConn {
	tcp_socket :=  net.dial_tcp('$ws.uri.hostname:$ws.uri.port')?

	optval := int(1)
	tcp_socket.sock.set_option_int(.keep_alive, optval)?

	ws.conn.set_read_timeout(3 * time.second)
	ws.conn.set_write_timeout(3 * time.second)

	if ws.is_ssl {
		ws.connect_ssl()?
	}

	return tcp_socket
}

