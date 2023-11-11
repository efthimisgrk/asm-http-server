# asm-http-server

A simple HTTP web server written in x86 assembly (Intel syntax) during the pwn.college journey. It forks and handles both GET and POST HTTP requests, and does some simple file I/O.

**GET** searches the filesystem for the file specified in the URL path. If it finds it, it returns its contents in the response. If not, it returns nothing.

**POST** writes the data contained in the HTTP body to the filesystem in the location specified by the URL path. If the file exists, it will overwrite it.

#### Disclaimer

It's low-level, messy, and definitely not secure.

#### Usage

Assemble it:

```
as ./server.s -o ./server.o
```

Link the object file:
```
ld ./server.o -o ./server
```

Set the `CAP_NET_BIND_SERVICE` capability to bind to TCP port 80:

```
sudo setcap 'cap_net_bind_service=+ep' ./server
```

Run the web server `./server` and visit `http://127.0.0.1/`.
