module websocket

import net.openssl
import emily33901.net

const (
	is_used = openssl.is_used
)

fn C.SSL_get_error() int

// Todo: move this to openssl lib later

pub struct SSLConn {
mut:
	sslctx            &C.SSL_CTX
	ssl               &C.SSL
	handle			  &int
}

pub fn new_ssl_conn() &SSLConn {
	return &SSLConn {
		sslctx: 0
		ssl: 0
		handle: &int(0)
	}
}

// shutdown closes the ssl connection and cleans up
pub fn (mut s SSLConn) shutdown()? {
	if s.ssl!=0 {
		mut res := int(C.SSL_shutdown(s.ssl))
		s.ssl_error(res)?
		C.SSL_free(s.ssl)
		// s.ssl = 0
	}
	if s.sslctx != 0 {
		C.SSL_CTX_free(s.sslctx)
	}
}

// connect to server using open ssl
pub fn (mut s SSLConn) connect(mut tcp_conn &net.TcpConn)? {
	s.handle = &tcp_conn.sock.handle

	C.SSL_load_error_strings()
	s.sslctx = C.SSL_CTX_new(C.SSLv23_client_method())
	if s.sslctx == 0 {
		return error("Couldn't get ssl context")
	}
	
	s.ssl = C.SSL_new(s.sslctx)
	if s.ssl == 0 {
		return error("Couldn't create OpenSSL instance.")
	}
	if C.SSL_set_fd(s.ssl, tcp_conn.sock.handle) != 1 {
		return error("Couldn't assign ssl to socket.")
	}
	if C.SSL_connect(s.ssl) != 1 {
		return error("Couldn't connect using SSL.")
	}

	return none

}

pub fn (mut s SSLConn) read_into(mut buffer []Byte)? int {
	mut res := 0
	res = C.SSL_read(s.ssl, buffer.data, buffer.len)

	if res <= 0 {
		err_res := s.ssl_error(res)?
		if err_res == C.SSL_ERROR_ZERO_RETURN {
			return 0
		} else {
			return error('WRITE GOT ERROR RESULTS FROM SSL ERROR $err_res')
		}
		// Todo: fix timeout etc for SSL like Emily connection
	}
	return res
}

// write number of bytes to SSL connection
pub fn (mut s SSLConn) write(bytes []byte)? {
	mut ptr_base := byteptr(bytes.data)
	mut total_sent := 0
	for total_sent < bytes.len {
		ptr := unsafe{ ptr_base + total_sent }
		remaining := bytes.len - total_sent
		mut sent := C.SSL_write(s.ssl, ptr, remaining)
		if sent < 0 {
			err_res := s.ssl_error(sent)?
			if err_res == C.SSL_ERROR_ZERO_RETURN {
				return error('ssl write on closed connection')
			} else {
				return error('WRITE GOT ERROR RESULTS FROM SSL ERROR $err_res')
			}
			// Todo checkf or write waits like Emily sockets
		}
		total_sent += sent
	}
	unsafe {
		free(bytes)
	}
}

// Todo: fix better messages 
// ssl_error returns non error ssl code or error if unrecoverable and we should panic
fn (mut s SSLConn) ssl_error(ret int)? int{
	res := C.SSL_get_error(s.ssl, ret)
	match res {
		C.SSL_ERROR_SYSCALL {
			return error('unrecoverable syscall')
		}
		C.SSL_ERROR_SSL {
			return error('unrecoverable ssl protocol error')
		}
		else {
			return res
		}

	}
}