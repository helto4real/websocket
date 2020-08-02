module websocket

import emily33901.net

fn error_code() int {
	return C.WSAGetLastError()
}

const (
	error_ewouldblock = net.WsaError.wsaewouldblock
)
