# Verilog_TCP

-- IN PROGRESS, Nothing done yet --

Highly specialized TCP module.\
Simple and high-performance.\
No ARP support. No need to worry about uncertain latencies caused by ARP packets.
Only work as a client.\
Create connection once and only once after power on.\
\
Optional Heartbeat packet support so that the server will not trigger a ARP timeout.\
Optional jumbo frame support.\
Optional download support. (A ack packet will be sent to server immediately after receiving a packet, it may cause additional latency for the upload stream.)

## Parameters

- **IP** \
    the IP address of the module \
    default: $192.168.2.240$
- **remote_IP** \
    the IP address of the server \
    default: $192.168.2.241$
- **MAC** \
    the MAC address of the module \
    default: $06:00:AA:BB:CC:DD$
- **remote_MAC** \
    the MAC address of the server \
    default: $06:00:AA:BB:CC:DE$
- **port** \
    the local port of the module \
    default: $12345$
- **remote_tport** \
    the remote port of the server \
    default: $23456$

- **resend_interval** \
    the interval of resend packet (in clock cycles) \
    default: $1000000$ (1M)

- **tx_buf_size** \
    the size of send buffer (in bytes) \
    default: $16384$

- **HB** \
    enable heartbeat packet \
    default: $1$

- **HB_interval** \
    the interval of heartbeat packet (in clock cycles) \
    default: $100000000$ (100M)

- **jumbo** \
    -- IN PROGRESS -- \
    enable jumbo frame support (MTU = 9000) \
    default: $0$

- **download** \
    -- IN PROGRESS -- \
    enable download support \
    default: $0$

- **rx_buf_size** \
    the size of receive buffer (in bytes) \
    default: $1024$

## Ports

```plaintext
in clk 
in rst_n 

in tx_data 64bits 
in tx_valid 
in tx_cnt 3bits 0 = 1byte, 7 = 8bytes
out tx_ready

out rx_data 64bits
out rx_valid
out rx_cnt 3bits 0 = 1byte, 7 = 8bytes
in rx_ready

out tx_net_data 64bits
out tx_net_valid
out tx_net_cnt 3bits 0 = 1byte, 7 = 8bytes
in tx_net_ready
out tx_net_fin

in rx_net_data 64bits
in rx_net_valid
in rx_net_cnt 3bits 0 = 1byte, 7 = 8bytes
out rx_net_ready
in rx_net_fin
```
