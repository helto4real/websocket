// The module websocket implements the websocket server capabilities
module websocket

import emily33901.net
import log
import sync
import time 
import rand 

pub struct Server {
mut: 
	mtx               		&sync.Mutex = sync.new_mutex()
	clients					[]&ServerClient
	logger 					&log.Log
	ls 						net.TcpListener
	accept_client_callbacks []AcceptClientFn
	message_callbacks 		[]MessageEventHandler


pub:
	port int
	is_ssl bool = false

pub mut:
	ping_interval 	int = 30
	state    		State
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
		logger: &log.Log{level: .info}
		state: .closed
	}
}

pub fn (mut s Server) set_ping_interval(seconds int) {
	s.ping_interval = seconds
}

pub fn (mut s Server) listen() ? {
	s.logger.info('start listen on port $s.port')
	s.ls = net.listen_tcp(s.port) ?
	s.set_state(.open)
	go s.handle_ping()
	for {
		c := s.accept_new_client() or { continue }
		go s.serve_client(mut c)
	}
	s.logger.info('End listen on port $s.port')
}

fn (mut s Server) close() {
	
}

// Todo: make thread safe
fn (mut s Server) handle_ping() {
	mut unix_time := time.now().unix
	for s.state == .open {
		time.sleep_ms(100)
		now := time.now().unix
		diff := now - unix_time
		mut clients_to_remove := []&ServerClient{}
		if diff >= s.ping_interval {
			unix_time = now
			for x, _ in s.clients {
					mut c := s.clients[x]
					if c.client.state == .open {
						c.client.ping() or {
							s.logger.debug('error sending ping to client')
							// todo fix better close message
							c.client.close(1000, 'ping send error') or {
								// we want to continue even if error
								continue
							}
							clients_to_remove << c
						}
					}
				
			}
			for x, _ in s.clients {
				mut c := s.clients[x]
				if c.client.state == .open && (time.now().unix - c.client.last_pong_ut) > s.ping_interval*2 {
					clients_to_remove << c
					c.client.close(1000, 'no pong received') or {
						continue
					}	
				}
			}
			for cr in clients_to_remove {
				s.clients.delete(cr)
			}
		}

	}
}

fn (mut s Server) serve_client(mut c Client)? {
	handshake_response, server_client := s.handle_server_handshake(mut c)?

	accept := s.send_connect_event(mut server_client)?
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
		last_pong_ut: time.now().unix
		id: rand.uuid_v4()
	}
	return c
}

[inline]
// set_state sets current state in a thread safe way
fn (mut s Server) set_state(state State) {
	s.mtx.m_lock()
	s.state = state
	s.mtx.unlock()
}