# HTTPX Automation

`httpx-auto.sh` runs HTTP probing and checks common metadata and well-known
endpoints for a list of subdomains. Use it only with systems you own or are
authorized to test.

## Requirements

- Bash
- ProjectDiscovery `httpx` installed and available on your `PATH`
- Standard command-line utilities: `grep`, `sort`, `wc`, and `mkdir`

The script optionally uses `/opt/httpx/model.json` for knowledge-base and
error/parked fingerprint scans. If the file is absent, those two scans are
skipped; the other checks still run.

## Run

From the `Automation` directory:

```bash
chmod +x httpx-auto.sh
./httpx-auto.sh
```

When prompted, enter the path to a `.txt` file containing subdomains, for
example `subdomains.txt` or `/path/to/subdomains.txt`.

## Input format

Enter one subdomain per line. Blank lines and lines whose first non-whitespace
character is `#` are ignored, and duplicate entries are removed.

```text
example.com
api.example.com
# staging.example.com
```

## Checks performed

- Probes targets for status code, page title, content length, redirect
  location, CNAME, server, and detected technologies.
- When `/opt/httpx/model.json` exists, runs knowledge-base detection and
  error/parked fingerprint checks.
- Checks for `robots.txt`, `sitemap.xml`, `humans.txt`, `ads.txt`, OpenID
  configuration, Apple and Android association files, and `crossdomain.xml`.
- Checks the security.txt, change-password, and OpenID configuration
  well-known endpoints.

The script filters out HTTP 404 and 401 responses for its general scans.
Common-file checks also require HTTP 200 and their configured content matchers.

## Output

The script creates an `httpx-results/` directory in the current working
directory. It contains the normalized target list (`targets.txt`) and results
for the probes, model scans (when available), common files, and well-known
endpoints. Existing files with the same names may be overwritten on a later
run.

The results are organized like this:

```text
httpx-results/
├── targets.txt
├── httpx.txt
├── httpx-kb.jsonl
├── httpx-fingerprints.txt
├── robots.txt
├── sitemap.txt
├── humans.txt
├── ads.txt
├── openid.txt
├── apple-app-site-association.txt
├── android-assetlinks.txt
├── crossdomain.txt
└── well-known.txt
```

`httpx-kb.jsonl` and `httpx-fingerprints.txt` are only created when the model
file is available. If a scan finds no matching results, its output file may
not be created.
