.intel_syntax noprefix
.global _start

.section .text

_start:

    # Create a socket (AF_INET, SOCK_STREAM, IPPROTO_IP) and store the file descriptor in r13
    mov rdi, 2                # Address family: AF_INET
    mov rsi, 1                # Socket type: SOCK_STREAM
    xor rdx, rdx              # Protocol: IPPROTO_IP
    mov rax, 41               # socket() syscall number
    syscall

    mov r13, rax              # Store the socket file descriptor in r13

    # Bind the socket to a specific address and port
    mov rdi, r13
    mov rcx, rsp
    sub rcx, 16
    mov WORD PTR [rcx], 0x02         # sa_family=AF_INET
    mov WORD PTR [rcx + 2], 0x5000   # sin_port=htons(80)
    mov DWORD PTR [rcx + 4], 0       # sin_addr=inet_addr("0.0.0.0")
    mov rsi, rcx
    mov rdx, 16
    mov rax, 49               # bind() syscall number
    syscall

    # Listen for incoming connections
    xor rsi, rsi
    mov rax, 50               # listen() syscall number
    syscall

accept:

    # Accept an incoming connection and store the new file descriptor in r14
    mov rdi, r13              # The file descriptor of the socket
    xor rsi, rsi
    xor rdx, rdx
    mov rax, 43               # accept() syscall number
    syscall

    mov r14, rax              # Store the accepted connection file descriptor in r14

    # Fork the process
    mov rax, 57               # fork() syscall number
    syscall

    test rax, rax
    jnz parent
    jz child

parent:

    # Close the file descriptor for the accepted connection (child will handle it)
    mov rdi, r14
    mov rax, 3                # close() syscall number
    syscall

    jmp accept

child:

    # Close the original listening socket
    mov rdi, r13
    mov rax, 3                # close() systcall number
    syscall

    # Read the incoming HTTP request into the buffer at rsp
    mov rdi, r14
    sub rsp, 1024             # Allocate space for the incoming request
    mov rsi, rsp              # Buffer address
    mov rdx, 1024             # Read up to 1024 bytes
    xor rax, rax              # read() syscall number
    syscall

    # Save the actual request size
    mov [rsp - 32], rax

    # Get the memory address where <path> starts in the request
    mov rdi, rsp
    call check_for_space      # Get the address of the first whitespace
    inc rax                   # Increment by one to get the address of the '/'
    push rax
    mov rdi, rax
    call check_for_space      # Get the address of the next space
    mov BYTE PTR [rax], 0     # Turn the space to a null byte
    pop rdi                   # Pop the <path> from the stack to rdi

    # Check the HTTP method to determine if it's a GET or POST request
    cmp DWORD PTR [rsp], 0x54534f50   # Compare the first 4 bytes of the request with 'POST'
    je POST
    cmp DWORD PTR [rsp], 0x20544547   # Compare the first 4 bytes of the request with 'GET '
    je GET
    jne BAD_REQUEST

POST:

    # Open a file for writing
    mov rsi, 0101             # O_WRONLY|O_CREAT
    mov rdx, 0777             # File permissions
    mov rax, 2                # open() syscall number
    syscall

    mov r15, rax              # Store the file descriptor in r15

    # Write the contents of the HTTP request to the file
    mov rdi, rsp
    call check_for_rnrn       # Identify where headers end
    mov rsi, rax
    add rsi, 4
    mov rdx, rsp              # rsp points to the start of the request in memory
    add rdx, [rsp - 32]       # Add the request size to this
    sub rdx, rsi              # Subtract the memory address  
    mov rdi, r15              # The file descriptor to the opened file 
    mov rax, 1                # write() syscall number
    syscall

    # Close the file
    mov rdi, r15              # The file descriptor of the file
    mov rax, 3                # close() syscall number
    syscall

    # Write a success response to the accepted connection
    mov rdi, r14              # The file descriptor of the accepted connection 
    lea rsi, SUCCESS_RESPONSE
    mov rdx, 19
    mov rax, 1                # write() syscall number
    syscall

    jmp EXIT

GET:

    # Open the file indicated by the <path> for reading (rdi holds the <path> value already)
    xor rsi, rsi
    mov rax, 2                # open() systcall number
    syscall

    mov r15, rax              # Store the file descriptor in r15

    # Read the contents of the file into the buffer at rsp
    mov rdi, r15              # File descriptor of the file
    mov rsi, rsp              # The buffer where the file data will be stored
    mov rdx, 512              # Read up to 512 bytes
    xor rax, rax              # read() syscall number
    syscall

    mov [rsp - 8], rax        # Save the number of bytes read

    # Close the file
    mov rax, 3                # close() syscall number
    syscall

    # Write a success response to the accepted connection
    mov rdi, r14              # The file descriptor of the accepted connection 
    lea rsi, SUCCESS_RESPONSE
    mov rdx, 19
    mov rax, 1                # write() syscall number
    syscall

    # Write the contents of the file to the accepted connection
    mov rsi, rsp              # The file descriptor of the accepted connection 
    mov rdx, [rsp - 8]
    mov rax, 1                # write() syscall number
    syscall
    
    jmp EXIT

BAD_REQUEST:

    # Write a bad request response to the accepted connection
    mov rdi, r14              # The file descriptor of the accepted connection 
    lea rsi, BAD_REQUEST_RESPONSE
    mov rdx, 28
    mov rax, 1                # write() syscall number
    syscall

    jmp EXIT

EXIT:

    # Restore the stack to its original state
    add rsp, 1024

    # Exit the program
    xor rdi, rdi
    mov rax, 60               # exit() syscall number
    syscall

# Function to check for whitespace in a string
check_for_space:
    cmp BYTE PTR [rdi], 0x20   # Check for a space character
    je found_space
    inc rdi
    jne check_for_space
found_space:
    mov rax, rdi              # Return the memory address where tha space character is located
    ret

# Function to check for '\r\n\r\n' in a string
check_for_rnrn:
    cmp DWORD PTR [rdi], 0x0a0d0a0d  # Check for '\r\n\r\n'
    je found_rnrn
    inc rdi
    jne check_for_rnrn
found_rnrn:
    mov rax, rdi              # Return the memory address where tha line feeds are located
    ret

.section .data

SUCCESS_RESPONSE:
.string "HTTP/1.0 200 OK\r\n\r\n"

BAD_REQUEST_RESPONSE:
.string "HTTP/1.0 400 Bad Request\r\n\r\n"