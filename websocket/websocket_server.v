// The module websocket implements the websocket server capabilities
module websocket

import emily33901.net
import log

pub struct Server {
mut: 
	clients	[]&ServerClient
	logger &log.Log
	ls net.TcpListener
	accept_client_callbacks []AcceptClientFn

pub:
	port int
	is_ssl bool = false
}

struct ServerClient {
mut: 	
	resource_name string
	client &Client
}

pub fn new_server(port int, route string) &Server{

	return &Server {
		port: port
		logger: &log.Log{level: .debug}
	}
}

pub fn (mut s Server) listen() ? {
	s.logger.info('start listen on port $s.port')
	s.ls = net.listen_tcp(s.port) ?

	for {
		c := s.accept_new_client() or { continue }
		// s.clients << c
		go s.serve_client(mut c)
	}
}

fn (mut s Server) serve_client(mut c Client)? {
	handshake_response, resource_name := s.handle_server_handshake(mut c)?

	server_client := &ServerClient{
		resource_name: resource_name
		client: c
	}
	accept := s.send_accept_client_event(mut server_client)?
	if !accept {
		s.logger.debug('client not accepted')
		c.shutdown_socket() ?
		return none
	} 
	
	// The client is accepted
	c.socket_write(handshake_response.bytes()) ?
	s.clients << server_client
}

fn (mut s Server) accept_new_client() ?&Client{
	mut new_conn := s.ls.accept()?
	c := &Client{
		is_server: true
		conn: new_conn
		sslctx: 0
		ssl : 0
		logger: s.logger
	}
	return c
}