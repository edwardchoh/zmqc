#!/usr/bin/env node
# zmqc: a small but powerful command-line interface to ZMQ

## Usage:

## Examples:
# zmqc -r -t=SUB -c='tcp://127.0.0.1:5000'
#
# Subscribe to 'tcp://127.0.0.1:5000', reading messages from it and printing
# them to the console. This will subscribe to all messages by default.
#
# ls | zmqc -w -t=PUSH -b='tcp://*:4000'
#
# Send the name of every file in the current directory as a message from a
# PUSH socket bound to port 4000 on all interfaces. Don't forget to quote the
# address to avoid glob expansion.
#
# zmqc -r -t=PULL -c'tcp://127.0.0.1:5202' | tee $TTY | zmqc -w -t=PUSH -c='tcp://127.0.0.1:5404'
#
# Read messages coming from a PUSH socket bound to port 5202 (note that we're
# connecting with a PULL socket), echo them to the active console, and
# forward them to a PULL socket bound to port 5404 (so we're connecting with
# a PUSH).
#
# zmqc -n 10 -0 -r -t=PULL -b='tcp://*:4123' | xargs -0 grep 'pattern'
#
# Bind to a PULL socket on port 4123, receive 10 messages from the socket
# (with each message representing a filename), and grep the files for
# `'pattern'`. The `-0` option means messages will be NULL-delimited rather
# than separated by newlines, so that filenames with spaces in them are not
# considered two separate arguments by xargs.
#
# echo "hello" | zmqc -t=REQ -c='tcp://127.0.0.1:4000'
#
# Send the string "hello" through a REQ socket connected to localhost port
# 4000, print whatever you get back and finish. In this way, REQ sockets can
# be used for a rudimentary form of RPC in shell scripts.
#
# coproc zmqc -t=REP -b='tcp://*:4000'
# tr -u '[a-z]' '[A-Z]' <&p >&p &
# echo "hello" | zmqc -c REQ 'tcp://127.0.0.1:4000'
#
# First, start a ZeroMQ REP socket listening on port 4000. The 'coproc' shell
# command runs this as a shell coprocess, which allows us to run the next
# line, tr. This will read its input from the REP socket's output, translate
# all lowercase characters to uppercase, and send them back to the REP
# socket's input. This, again, is run in the background. Finally, connect a
# REQ socket to that REP socket and send the string "hello" through it: you
# should just see the string "HELLO" printed on stdout.

## History:
# Based on https://github.com/zacharyvoase/zmqc.git written in Python

## License:
# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
#
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

# For more information, please refer to <http://unlicense.org/>

Args = require 'arg-parser'
zmq = require 'zmq'

args = new Args 'zmqc', '0.1', 'A small but powerful command-line interface to ZMQ', 'https://github.com/edwardchoh/zmqc'

args.add
	name: 'delimiter'
	desc: "Separate messages on input/output should be delimited by NULL characters (instead of newlines). Use this if your messages may contain newlines, and you want to avoid ambiguous message borders."
	switches: ['-0', '--delimiter']
	default: '\0'
	value: 'delimiter'

args.add
	name: 'number'
	desc: "Receive/send only NUM messages. By default, zmqc lives forever in 'read' mode, or until the end of input in 'write' mode."
	switches: ['-n', '--NUM']
	default: 0

args.add
	name: 'type'
	desc: "Which type of socket to create. Must be one of 'PUSH', 'PULL', 'PUB', 'SUB', 'REQ', 'REP' or 'PAIR'."
	switches: ['-t', '--type']
	required: true
	value: 'type'

args.add
	name: 'read'
	desc: "Read messages from the socket onto stdout."
	switches: ['-r', '--read']

args.add
	name: 'write'
	desc: "Write messages from stdin to the socket."
	switches: ['-w', '--write']

args.add
	name: 'bind'
	desc: "Bind to the specified address(es)."
	switches: ['-b', '--bind']
	value: 'bind'

args.add
	name: 'connect'
	desc: "Connect to the specified address(es)."
	switches: ['-c', '--connect']
	value: 'connect'

args.add
	name: 'options'
	desc: "Socket option names and values to set on the created socket. Consult `man zmq_setsockopt` for a comprehensive list of options. Note that you can safely omit the 'ZMQ_' prefix from the option name. If the created socket is of type 'SUB', and no 'SUBSCRIBE' options are given, the socket will automatically be subscribed to everything."
	switches: ['-o', '--options']
	value: 'options'

args.add
	name: 'topic'
	desc: "Specify topic for PUB or SUB socket. Defaults to all topics"
	switches: ['-t', '--topic']
	value: 'topic'
	default: ''

splitBuffer = (buf, delim) ->
	arr = []
	p = 0

	for i in [0..buf.length-1]
		continue if buf[i] != delim
		if i == 0
			p = 1
			continue # skip if delim is at the start of buffer
		else
			arr.push buf.slice(p, i)
			p = i + 1

	if arr.length == 0
		# just return the buf if delim not found
		return buf

	if p < buf.length
		# add final part
		arr.push buf.slice(p, buf.length)
	arr

main = ->
	sock = zmq.socket args.params.type
	if args.params.bind
		sock.bindSync args.params.bind
	else
		sock.connect args.params.connect

	if args.params.write
		process.stdin.on 'readable', () ->
			chunk = process.stdin.read()
			if chunk != null
				sock.send splitBuffer(chunk, args.params.delimiter)
	else
		sock.on 'message', (data) ->
			process.stdout.write data

if not args.parse()
	return args.help()

args.params.type = args.params.type.toLowerCase()

# Check for conformance
if (args.params.read and args.params.write) or (not args.params.read and not args.params.write)
	console.warn "Must specify either --read or --write" 
else if (args.params.bind and args.params.connect) or (not args.params.bind and not args.params.connect)
	console.warn "Must specify either --bind or --connect" 
else if args.params.write and args.params.type == 'sub'
	console.warn "Cannot write to a SUB socket" 
else if args.params.read and args.params.type == 'pub'
	console.warn "Cannot read from a PUB socket" 
else
	return main()

args.help()
return