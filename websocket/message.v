module websocket

const(
	header_len_offset 			= 2
	buffer_size 				= 256
	extended_payload16_end_byte = 4
	extended_payload64_end_byte = 10
)

struct Fragment {
	data 	[]byte
	opcode 	OPCode
}

struct Frame {
mut:
	header_len  u64		= u64(2)
	frame_size  u64		= u64(2)
	fin         bool
	rsv1        bool
	rsv2        bool
	rsv3        bool
	opcode      OPCode
	has_mask    bool
	payload_len u64
	masking_key [4]byte
}

const (
	invalid_close_codes = [999, 1004, 1005, 1006, 1014, 1015, 1016, 1100, 2000, 2999, 5000, 65536]
)

// validate_client, validate client frame rules from RFC6455
pub fn (mut ws Client) validate_frame(frame &Frame) ? {

	if frame.rsv1 || frame.rsv2 || frame.rsv3 {
		ws.close(1002, 'rsv cannot be other than 0, not negotiated')
		return error('rsv cannot be other than 0, not negotiated')
	}

	if (int(frame.opcode) >=3 && int(frame.opcode) <=7) || (int(frame.opcode) >=11 && int(frame.opcode) <=15) {
		ws.close(1002, 'use of reserved opcode') ?
		return error('use of reserved opcode')
	}

	if frame.has_mask {
		// Server should never send masked frames 
		// to client, close connection
		ws.close(1002, "client got masked frame") ?
		return error("client sent masked frame")
	}
	if frame.opcode  !in [.text_frame, .binary_frame, .continuation] {
		// This is controlframe
		if !frame.fin {
			ws.close(1002, 'control message must not be fragmented') ?
			return error('unexpected control frame with no fin')
		}
		
		if frame.payload_len > 125 {
			ws.close(1002, 'control frames must not exceed 125 bytes') ?
			return error('unexpected control frame payload length')
		}

	}
	if frame.fin == false && ws.fragments.len == 0 && frame.opcode == .continuation {
		ws.close(1002, 'unexecpected continuation, there are no frames to continue') ?
		return error('unexecpected continuation, there are no frames to continue')
	}


	return none 
}

[inline]
fn is_control_frame(opcode OPCode) bool {
	return opcode !in [.text_frame, .binary_frame, .continuation]
}

[inline]
fn is_data_frame(opcode OPCode) bool {
	return opcode in [.text_frame, .binary_frame]
}

[inline]
fn (mut ws Client) read_payload(payload_len u64) ?[]byte {

	if payload_len == 0 {
		return []byte{}
	}

	// TODO: make a dynamic reusable memory pool here
	mut buffer := []byte{cap: int(payload_len)}
	mut read_buf := []byte{len: 1}
	mut bytes_read := u64(0)

	for bytes_read < payload_len {
		len := ws.socket_read_into(mut read_buf) ?
		if len != 1 {
			return error('expected read all message, got zero')
		}
		bytes_read++
		buffer << read_buf[0]
	}

	if bytes_read != payload_len {
		return error('failed to read payload')
	}

	return buffer
}

fn (mut ws Client) validate_utf_8(opcode OPCode, payload []byte) ? {

	if opcode in [.text_frame, .close] && !utf8_validate(payload) {
		ws.logger.error('malformed utf8 payload')
		// ws.send_error_event('Recieved malformed utf8.')
		ws.close(1007, 'malformed utf8 payload')
		return error('malformed utf8 payload')
	}	
	return none
}
// read_next_message reads 1 to n frames to compose a message
pub fn (mut ws Client) read_next_message() ?&Message {
	for {
		frame := ws.parse_frame_header() ?
		ws.logger.debug('frame:\n$frame')

		ws.validate_frame(&frame) ?
		
		mut frame_payload := ws.read_payload(frame.payload_len)?

		if is_control_frame(frame.opcode) {
			// Control frames can interject other frames
			// and need to be returned directly
			return &Message{
				opcode: OPCode(frame.opcode)
				payload: frame_payload
			}
		}

		// If the message is fragmented we just put it on fragments 
		// a fragment is allowed to be of zero size of data
		if !frame.fin  {
			// ws.validate_utf_8(frame.opcode, frame_payload) ?
			ws.fragments << &Fragment {
				data: frame_payload
				opcode: frame.opcode
			}
			continue
		}

		// Not fragments to put togehter just return the frame as message
		if ws.fragments.len == 0 {
			ws.validate_utf_8(frame.opcode, frame_payload) ?
			return &Message{
				opcode: OPCode(frame.opcode)
				payload: frame_payload
			}
		}

		defer {ws.fragments = []}
		// println('HERE')
		if is_data_frame(frame.opcode) {
			// Todo: this may include reserved future
			// opcode range as well
			ws.close(0, '') ?
			return error('Unexpected frame opcode')
		}
		payload := ws.payload_from_fragments(frame_payload) ?
		opcode := ws.opcode_from_fragments() 
		// println('fragments: $ws.fragments, buffer: $payload, opcode: $opcode, frame: $frame')
		ws.validate_utf_8(opcode, payload) ?
		return &Message{
			opcode: opcode
			payload: payload
		}
	}

}

[inline]
fn (ws Client) payload_from_fragments(fin_payload []byte) ?[]byte {
	mut size := 0
	// calculate total length
	for f in ws.fragments {
		if f.data.len > 0 {
			size += f.data.len
		}
	}

	size += fin_payload.len

	if size == 0 {
		return []byte{}
	}

	mut total_buffer := []byte{cap: size}
	for f in ws.fragments {
		if f.data.len > 0 {
			total_buffer << f.data
		}
	}
	total_buffer << fin_payload
	return total_buffer
}

// frame_opcode_from_fragments
fn (ws Client) opcode_from_fragments() OPCode {
	return OPCode(ws.fragments[0].opcode)
}
// parse_frame_header parses next message by decoding the incoming frames 
pub fn (mut ws Client) parse_frame_header() ? Frame {

	// TODO: make a dynamic reusable memory pool here
	mut buffer := []byte{cap: buffer_size}
	
	// mut bytes_read 	:= u64(0)
	mut frame 			:= Frame{}
	mut rbuff 			:= []byte{len:1}
	mut mask_end_byte 	:= 0 

	for ws.state == .connected  {
		// Todo: different error scenarios to make sure we close correctly on error
		// reader.read_into(mut rbuff) ?
		read_bytes := ws.socket_read_into(mut rbuff) ?
		if read_bytes == 0 {
			// This is probably a timeout or close
			continue
		}
		buffer << rbuff[0]
		// bytes_read++
		
		// parses the first two header bytes to get basic frame information
		if buffer.len == u64(header_len_offset) {
			frame.fin = (buffer[0] & 0x80) == 0x80
			frame.rsv1 = (buffer[0] & 0x40) == 0x40
			frame.rsv2 = (buffer[0] & 0x20) == 0x20
			frame.rsv3 = (buffer[0] & 0x10) == 0x10
			frame.opcode = OPCode(int(buffer[0] & 0x7F))
			frame.has_mask = (buffer[1] & 0x80) == 0x80
			frame.payload_len = u64(buffer[1] & 0x7F)
		
			// if has mask set the byte postition where mask ends
			if frame.has_mask {
				mask_end_byte = if frame.payload_len < 126 {
					header_len_offset + 4
				} else if frame.payload_len == 126 {
					header_len_offset + 6
				} else if frame.payload_len == 127 {
					header_len_offset + 8
				} else {0} // Impossible
			}
			frame.payload_len = frame.payload_len
			frame.frame_size = u64(frame.header_len) + frame.payload_len

			if !frame.has_mask && frame.payload_len < 126 {
				return frame
			}			
		}

		if frame.payload_len == 126 && buffer.len == u64(extended_payload16_end_byte) {
			frame.header_len += 2
			
			frame.payload_len = 0
			frame.payload_len |= buffer[2] << 8
			frame.payload_len |= buffer[3] << 0
			frame.frame_size = u64(frame.header_len) + frame.payload_len

			if !frame.has_mask {
				return frame
			}	
		}

		if frame.payload_len == 127 && buffer.len == u64(extended_payload64_end_byte) {
			frame.header_len += 8 // TODO Not sure...
			frame.payload_len = 0

			frame.payload_len |= u64(buffer[2]) << 56
			frame.payload_len |= u64(buffer[3]) << 48
			frame.payload_len |= u64(buffer[4]) << 40
			frame.payload_len |= u64(buffer[5]) << 32
			frame.payload_len |= u64(buffer[6]) << 24
			frame.payload_len |= u64(buffer[7]) << 16
			frame.payload_len |= u64(buffer[8]) << 8
			frame.payload_len |= u64(buffer[9]) << 0

			if !frame.has_mask {
				return frame
			}	
		}

		// We have a mask and we read the whole mask data
		if  frame.has_mask && buffer.len == mask_end_byte {
			frame.masking_key[0] = buffer[mask_end_byte-4]
			frame.masking_key[1] = buffer[mask_end_byte-3]
			frame.masking_key[2] = buffer[mask_end_byte-2]
			frame.masking_key[3] = buffer[mask_end_byte-1]
			
			return frame
		}
	}
	return frame
}

[inline]
// unmask_sequence unmask any given sequence  
fn (f Frame) unmask_sequence(mut buffer[]byte) {
	for i in 0 .. buffer.len {
		buffer[i] ^= f.masking_key[i % 4] & 0xff
	}
}
