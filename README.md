# Verilog_TCP

-- IN PROGRESS --

The code is currently a mess and will be gradually modified later.


- [x] Establish Connection
- [ ] Connection State Management
- [ ] Data Transmission
- [ ] Data Receiving
- [ ] Heartbeat
- [ ] Sliding Window
- [ ] 1Gbps Support
- [ ] 10Gbps Support
- [ ] Code Style Optimization

Highly specialized TCP module.\
Simple and high-performance.\
~~No ARP support. No need to worry about uncertain latencies caused by ARP packets.~~ \
Only ARP boardcast support.\
Only works as a client.\
Create connection once and only once after power on.\
~~No reconnection support.~~\
Reconnect using the RST flag and never send the FIN flag.\
No TCP fast retransmission support.\
\
Optional Heartbeat packet support so that the server will not trigger a ARP timeout.\
Optional jumbo frame support.\
Optional download support. (A ack packet will be sent to server immediately after receiving a packet, it may cause additional latency for the upload stream.)

## Parameters

-- WIP --

## Ports

-- WIP --
