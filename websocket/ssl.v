module websocket

import net.openssl

const (
	is_used = openssl.is_used
)

fn (mut ws Client) shutdown_ssl() {
	C.SSL_shutdown(ws.ssl)
	C.SSL_free(ws.ssl)
	if ws.sslctx != 0 {
		C.SSL_CTX_free(ws.sslctx)
	}
}

fn (mut ws Client) connect_ssl() ? {
	// l.i('Using secure SSL connection')
	C.SSL_load_error_strings()
	ws.sslctx = C.SSL_CTX_new(C.SSLv23_client_method())
	if ws.sslctx == 0 {
		return error("Couldn't get ssl context")
	}
	ws.ssl = C.SSL_new(ws.sslctx)
	if ws.ssl == 0 {
		return error("Couldn't create OpenSSL instance.")
	}
	if C.SSL_set_fd(ws.ssl, ws.conn.sock.handle) != 1 {
		return error("Couldn't assign ssl to socket.")
	}
	if C.SSL_connect(ws.ssl) != 1 {
		return error("Couldn't connect using SSL.")
	}
}
