module websocket

import emily33901.net

fn test_compile() {
	ws := new_client('ws://some.address.com:80') or {
		panic(err)
	}
	assert true
}


// These tests will work once interface works

// struct FakeReader {
// mut:
// 	pos    int
// 	stream []byte
// }

// fn (mut fr FakeReader) read_into(mut buffer []byte) ?int {
// 	if fr.pos >= fr.stream.len {
// 		return error('EOL')
// 	}
// 	// println(buffer.len)
// 	x := fr.stream[fr.pos..buffer.len]
// 	fr.pos += buffer.len
// 	return buffer.len
// 	// buffer.insert(x)
// }


// fn test_parse_basic_frame_parsing() {
// 	// panic("TEST")
// 	ws := &Client{
// 		conn: &net.TcpConn{}
// 	}
// 	mut header := []byte{cap: 3}
// 	// finish and one lenght no reserved bits
// 	header << 0b10000001 // finish bit 7, and text frame
// 	header << 0b00000001 // 0000 0001
// 	header << `A`
// 	fk := FakeReader{
// 		stream: header
// 	}
// 	frame := ws.parse_frame_header(fk) or {
// 		Frame{}
// 	}
// 	println(frame)
// 	assert frame.fin == true
// }
