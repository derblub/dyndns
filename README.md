# Dynamic DNS to use with your Plesk server
Shell script to remotely update the A-record of a subdomain DNS entry, managed by a Plesk server.

##Installation:
1. Create a subdomain in Plesk to use as your dynamic DNS hostname (no hosting required)
2. _optional:_ edit `SOA` record of subdomain, change `TTL` to a low value to make things faster
3. copy `config.example` to `~/.config/dyndns/config`, `chmod 600` it and fill in your values (the script refuses to run without it; set `DYNDNS_CONFIG` to use another path)
4. create a crontab on your local machine to run every n minutes (`*/5 * * * *   sh dyndns.sh`)
5. ???
6. profit!


##@todo:
- better error handling
- create subdomain from script
- make more things optional
- ...

---
### Tested with:
- Plesk 10
- Plesk 11.5

For any other version, first make sure the column exists and is in use by Plesk. To update your bind adresses, you'll also need the `dnsmng` tool by Plesk, alternativly you can update DNS cache yourself of course.
