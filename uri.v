module websocket

struct Uri {
mut:
	hostname    string
	port        string
	resource    string
	querystring string
}