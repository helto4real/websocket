# New V-websocket library

This is a refactor of the current web socket library to comply with V-like style of programming. It is built on top of Emily net library and passes all the autobahn tests for clients. 

## Changes from original websocket implementation

- Use only built-in datatypes, no voidptrs or byteptr
- Relying on V automatic free of resources (not done yet)
- Comply to autobahn tests excluding compression
- Use new socket implementation from Emily that will soon be standard in V
- Use Option error handling 
- Refactor code so websocket.v contains only the code to understand basic implementations
    - moved communication to io.v
    - separation of handling frames and finished messages
- Eventbus is using option as callback function for better error handling

## Proposed / planned changes

- Implement a autobahn compliant websocket server
- Strict comply to utf8 autobahn fast fail rule (it comply now but non strict)
- Generics, use typed params in callback functions (no voidptr), generic eventbus
- Interfaces, IO operations as interfaces for making tests more easy
- Publish as module
- Set own timeouts

## Remarks

- It should not be used in production since memory management is not done yet in V

## Attribution
- the original author @thecodrr 
- original code that was updated and moved to V
   https://github.com/thecodrr/vws