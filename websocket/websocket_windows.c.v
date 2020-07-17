module websocket

fn error_code() int {
	return C.WSAGetLastError()
}

const (
	error_ewouldblock = WsaError.wsaewouldblock
)
