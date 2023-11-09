# asm-http-server

Creating a basic HTTP web server in x86_64 assembly using the Intel syntax. It forks and handles both GET and POST HTTP requests and does some simple file I/O.

**GET** searches the filesystem for the file specified in the URL path. If it finds it, it returns its contents in the response. If not, it returns nothing.

**POST** writes the data contained in the HTTP body to the filesystem in the location specified by the URL path. If the file exists, it will overwrite it.

#### Disclaimer

It's low-level, messy, and definitely not safe.

#### Usage

Assemble it:

```
as server.s -o server.o
```

Link the object file:
```
ld server.o -o server
```

Run it (you may need root privileges).
