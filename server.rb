require 'socket'
require 'digest/sha1'

server = TCPServer.new('localhost', 2345)

loop do

  socket = server.accept
  STDERR.puts "Incoming Request"

  http_request = ""

  while (line = socket.gets) && (line != "\r\n")
    http_request += line
  end

  STDERR.puts http_request

  if matches = http_request.match(/^Sec-WebSocket-Key: (\S+)/)
    websocket_key = matches[1]
    STDERR.puts "Websocket handshake detected with key: #{ websocket_key}"
  else 
    STDERR.puts "Aborting non-websocket connection"
    socket.close
    next
  end 

  response_key = Digest::SHA1.base64digest([websocket_key, "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"].join)
  STDERR.puts "Reponding to handhake with key: #{response_key}"

  socket.write <<-eos
  HTTP/1.1 101 Switching Protocols
  Upgrade: websocket
  Connection: Upgrade
  Sec-WebSocket-Accept: #{ response_key }
  eos

  STDERR.puts "Handshake completed"
end



# Notes
# Sockets are endpoints for bidirectional communcation channels.  Sockets
# can communicate within a process, between processes on the same machine,
# or between different machines.  TCPSocket, UDPSocketsm etc