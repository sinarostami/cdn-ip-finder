# How CDN Fronting Works — Technical Details

## The Core Technique

CDN Fronting (also called Domain Fronting) works by exploiting how CDN providers route traffic internally.

### Normal HTTPS Request
```
Client → DNS lookup "psiphon-server.com" → gets Psiphon IP
Client → TLS handshake with SNI "psiphon-server.com"
Firewall sees SNI → BLOCKS it
```

### CDN Fronted Request
```
Client → DNS lookup "a248.e.akamai.net" → gets Akamai IP (not blocked)
Client → TLS handshake with SNI "a248.e.akamai.net" (not blocked)
Firewall sees Akamai SNI → ALLOWS it
Inside encrypted TLS: Host header = "psiphon-server.com"
Akamai CDN reads Host header → forwards to Psiphon server
```

## Why Iran Cannot Block This

Akamai hosts:
- Apple.com, Microsoft.com, Adobe.com
- Major banking sites
- Government websites
- News sites

Blocking Akamai = breaking Iran's economy

## IP Rotation

CDN IPs change frequently because:
- CDNs use anycast routing
- IPs are assigned dynamically per region
- Load balancing changes IPs

This is why these scripts need to be run regularly.

## Iranian ISP Differences

| ISP | Filtering Style |
|-----|----------------|
| MCI (Hamrahe Aval) | Strictest — IP + protocol filtering |
| MTN Irancell | Protocol-based — throttles rather than blocks |
| Rightel | Similar to Irancell |
| Shatel/TCI | Similar to MCI |

## check-host.net API

The scripts use check-host.net's free API:

```
GET https://check-host.net/check-tcp?host=IP:443&node=ir1.node.check-host.net
→ returns request_id

GET https://check-host.net/check-result/{request_id}
→ returns results from Iranian nodes
```

Result format:
```json
{
  "ir1.node.check-host.net": [{"time": 0.045, "address": "IP"}],
  "ir2.node.check-host.net": [{"error": "Connection timed out"}]
}
```
