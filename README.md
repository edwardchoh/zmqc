# zmqc: a small but powerful command-line interface to ZMQ

## Usage:

	zmqc -r -t=SUB -c='tcp://127.0.0.1:5000'

Subscribe to 'tcp://127.0.0.1:5000', reading messages from it and printing
them to the console. This will subscribe to all messages by default.

	ls | zmqc -w -t=PUSH -b='tcp://*:4000'

Send the name of every file in the current directory as a message from a
PUSH socket bound to port 4000 on all interfaces. Don't forget to quote the
address to avoid glob expansion.

	zmqc -r -t=PULL -c'tcp://127.0.0.1:5202' | tee $TTY | zmqc -w -t=PUSH -c='tcp://127.0.0.1:5404'

Read messages coming from a PUSH socket bound to port 5202 (note that we're
connecting with a PULL socket), echo them to the active console, and
forward them to a PULL socket bound to port 5404 (so we're connecting with
a PUSH).

	zmqc -n 10 -0 -r -t=PULL -b='tcp://*:4123' | xargs -0 grep 'pattern'

Bind to a PULL socket on port 4123, receive 10 messages from the socket
(with each message representing a filename), and grep the files for
`'pattern'`. The `-0` option means messages will be NULL-delimited rather
than separated by newlines, so that filenames with spaces in them are not
considered two separate arguments by xargs.

	echo "hello" | zmqc -t=REQ -c='tcp://127.0.0.1:4000'

Send the string "hello" through a REQ socket connected to localhost port
4000, print whatever you get back and finish. In this way, REQ sockets can
be used for a rudimentary form of RPC in shell scripts.

	coproc zmqc -t=REP -b='tcp://*:4000'
	tr -u '[a-z]' '[A-Z]' <&p >&p &
	echo "hello" | zmqc -c REQ 'tcp://127.0.0.1:4000'

First, start a ZeroMQ REP socket listening on port 4000. The 'coproc' shell
command runs this as a shell coprocess, which allows us to run the next
line, tr. This will read its input from the REP socket's output, translate
all lowercase characters to uppercase, and send them back to the REP
socket's input. This, again, is run in the background. Finally, connect a
REQ socket to that REP socket and send the string "hello" through it: you
should just see the string "HELLO" printed on stdout.

## History:

Based on https://github.com/zacharyvoase/zmqc.git written in Python