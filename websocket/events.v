module websocket

fn (mut ws Client) send_message_event(mut msg Message) ? {
	ws.eb.publish('on_message', mut ws, mut msg)
	ws.logger.debug('sending on_message event')
	return none
}

fn (mut ws Client) send_error_event(err string) ? {
	ws.eb.publish('on_error', mut ws, err)
	ws.logger.debug('sending on_error event')
	return none
}

fn (mut ws Client) send_close_event() ? {
	ws.eb.publish('on_close', mut ws, voidptr(0))
	ws.logger.debug('sending on_close event')
	return none
}

fn (mut ws Client) send_open_event() ? {
	ws.eb.publish('on_open', mut ws, voidptr(0))
	ws.logger.debug('sending on_open event')
	return none
}
