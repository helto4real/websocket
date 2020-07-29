# New V-websocket library

This is a refactor of the current web socket library to comply with V-like style of programming. It is built on top of Emily net library and passes all the autobahn tests for clients. 

## Changes from original websocket implementation

- Use only built-in datatypes, no voidptrs or byteptr (for now the eventbus require it for callbacks)
- Relying on V automatic free of resources (not done yet)
- Client and Server pass autobahn tests excluding compression
- Use new socket implementation from @Ememily33901 that will soon be standard in V
- Use Option error handling 
- Refactor code so websocket.v contains only the code to understand basic implementations
    - moved communication to io.v
    - separation of handling frames and finished messages
- Eventbus dependency removed and using own fn types. Now register callbacks with on_message, on_error, on_open, on_close functions
- Easy to use webbsocket server 

## Proposed / planned changes

 * [x] Make server autobahn compliant like client [Done]
 * [ ] Strict comply to utf8 autobahn fast fail rule (it comply now but non strict)
 * [ ] Generics, use vweb type of app instead of voidptr for reference
 * [ ] Interfaces, IO operations as interfaces for making tests more easy
 * [ ] Publish as module
 * [ ] Set own timeouts
 * [ ] Set if autoping in server = false if time is 0

## Remarks

- It should not be used in production since memory management is not done yet in V

## Attribution
- the original author of client @thecodrr 
- original code that was updated and moved to V
   https://github.com/thecodrr/vws
