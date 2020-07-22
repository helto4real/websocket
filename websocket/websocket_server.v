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
	message_callbacks []MessageEventHandler


pub:
	port int
	is_ssl bool = false
}

struct ServerClient {
pub:
	resource_name string
	client_key string
pub mut: 	
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
		go s.serve_client(mut c)
	}
	s.logger.info('End listen on port $s.port')
}

fn (mut s Server) serve_client(mut c Client)? {
	handshake_response, server_client := s.handle_server_handshake(mut c)?

	accept := s.send_accept_client_event(mut server_client)?
	if !accept {
		s.logger.debug('client not accepted')
		c.shutdown_socket() ?
		return none
	} 
		
	// The client is accepted
	c.socket_write(handshake_response.bytes()) ?
	s.clients << server_client

	if s.message_callbacks.len > 0 {
		for cb in s.message_callbacks {
			if cb.is_ref {
				c.on_message_ref(cb.handler2, cb.ref)
			} else {
				c.on_message(cb.handler)
			}
			
		}
	}
	c.listen() or {
		s.logger.error(err)
		return error(err)
	}
}

fn (mut s Server) accept_new_client() ?&Client{
	mut new_conn := s.ls.accept()?
	c := &Client{
		is_server: true
		conn: new_conn
		sslctx: 0
		ssl : 0
		logger: s.logger
		state: .open
	}
	return c
}