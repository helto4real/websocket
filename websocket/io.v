module websocket

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
	if ws.state == .closed || ws.conn.sock.handle <= 1 {
		println('Socket allready closed')
		return error('Socket allready closed')
	}
	ws.write_lock.m_lock()
	defer {
		ws.write_lock.unlock()
	}
	if ws.is_ssl {
		unsafe {
			mut ptr_base := byteptr(bytes.data)
			mut total_sent := 0
			for total_sent < bytes.len {
				ptr := ptr_base + total_sent
				remaining := bytes.len - total_sent
				mut sent := C.SSL_write(ws.ssl, ptr, remaining)
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
		}
	} else {
		ws.conn.write(bytes)?
	}
	return none
}

// shutdown_socket, proper shutdown make PR in Emeliy repo
fn (mut ws Client) shutdown_socket() ? {
	if ws.ssl != 0 {
		ws.shutdown_ssl()?
	} else {
		ws.conn.close()?
	}
	return none
}
