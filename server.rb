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

  STDERR.puts "Handshake completed. Starting to parse the websocket frame."

  first_byte = socket.getbyte
  fin = first_byte & 0b10000000
  opcode = first_byte & 0b00001111

  raise "We don't support continuations" unless fin
  raise "We only support opcode 1" unless opcode == 1

  second_byte = socket.getbyte
  is_masked = second_byte & 0b10000000
  payload_size = second_byte & 0b01111111

  raise "All frames sent to server should be masked" unless is_masked
  raise "Payloads > 126 bytes in length are not supported" unless payload_size < 126

  STDERR.puts "Payload size: #{ payload_size} bytes"

  mask = 4.times.map { socket.getbyte }
  STDERR.puts "Got mask: #{ mask.inspect }"

  data = payload_size.times.map { socket.getbyte }
  STDERR.puts "Masked data: #{ data.inspect }"

  unmasked_data = data.each_with_index.map { |byte, i| byte ^ mask[i % 4] }
  STDERR.puts "Unmasked the data: #{ unmasked_data.inspect}"

  STDERR.puts "Converted to a string #{ unmasked_data.pack('C*').force_encoding('utf-8').inspect }"

  socket.close
end



# Notes
# Sockets are endpoints for bidirectional communcation channels.  Sockets
# can communicate within a process, between processes on the same machine,
# or between different machines.  TCPSocket, UDPSocketsm etc