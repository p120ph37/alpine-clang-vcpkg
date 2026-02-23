#!/bin/bash
# claude-web-docker-setup.sh — Docker setup for the Claude Code web agent sandbox
#
# NOT for general-purpose developer use.  This script handles the specific
# constraints of the Claude Code web agent environment:
#   1. Starts dockerd with flags that work without iptables/overlayfs
#   2. Detects the TLS-intercepting proxy CA and extracts it
#   3. Configures Docker to route through the proxy
#   4. Provides a build wrapper that injects the proxy CA into Dockerfiles
#
# Usage:
#   source claude-web-docker-setup.sh    # set up environment + define functions
#   docker-build [docker build args...]  # build with auto CA injection
#
# The script is idempotent — safe to source multiple times.
set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────
PROXY_CA_PEM="${PROXY_CA_PEM:-/tmp/proxy-ca.pem}"
DOCKER_CONFIG_DIR="${HOME}/.docker"

# ── 1. Start Docker daemon ────────────────────────────────────────────────
#
# The sandbox environment lacks:
#   - iptables/nftables support → --iptables=false --ip6tables=false
#   - overlayfs kernel module   → --storage-driver=vfs
#   - bridge network support    → --bridge=none
#
# All container builds must use --network=host as a consequence.
setup_dockerd() {
    if docker info >/dev/null 2>&1; then
        echo "setup-docker: dockerd already running"
        return 0
    fi

    echo "setup-docker: starting dockerd..."
    dockerd \
        --iptables=false \
        --ip6tables=false \
        --bridge=none \
        --storage-driver=vfs \
        >/tmp/dockerd.log 2>&1 &

    # Wait for daemon to be ready (up to 30s)
    local i=0
    while ! docker info >/dev/null 2>&1; do
        sleep 1
        i=$((i + 1))
        if [ "$i" -ge 30 ]; then
            echo "setup-docker: ERROR — dockerd failed to start" >&2
            tail -20 /tmp/dockerd.log >&2
            return 1
        fi
    done
    echo "setup-docker: dockerd ready"
}

# ── 2. Extract proxy CA certificate ───────────────────────────────────────
#
# The sandbox routes HTTPS through a TLS-inspecting proxy whose CA is
# pre-installed in the host's trust store.  We extract it so Docker builds
# can install it inside containers.
#
# The CA subject is: "sandbox-egress-production TLS Inspection CA"
extract_proxy_ca() {
    if [ -f "$PROXY_CA_PEM" ]; then
        echo "setup-docker: proxy CA already at $PROXY_CA_PEM"
        return 0
    fi

    echo "setup-docker: extracting proxy CA certificate..."

    # Search the system CA bundle for the Anthropic egress proxy CA
    if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
        python3 -c "
import re, sys

with open('/etc/ssl/certs/ca-certificates.crt', 'r') as f:
    bundle = f.read()

# Split into individual PEM certificates
certs = re.findall(
    r'(-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----)',
    bundle, re.DOTALL
)

for cert_pem in certs:
    # Decode and check the subject for the proxy CA
    import base64, subprocess
    result = subprocess.run(
        ['openssl', 'x509', '-noout', '-subject'],
        input=cert_pem, capture_output=True, text=True
    )
    if 'sandbox-egress-production' in result.stdout or \
       'TLS Inspection' in result.stdout:
        with open('$PROXY_CA_PEM', 'w') as out:
            out.write(cert_pem + '\n')
        print(f'setup-docker: wrote proxy CA to $PROXY_CA_PEM')
        sys.exit(0)

# If not found via subject, try connecting through the proxy to detect it
print('setup-docker: proxy CA not found in system bundle, trying probe...',
      file=sys.stderr)
sys.exit(1)
" && return 0
    fi

    # Fallback: probe the proxy to extract the CA from a TLS connection
    if [ -n "${https_proxy:-}" ]; then
        python3 -c "
import socket, ssl, os, re, sys

proxy_url = os.environ.get('https_proxy', '')
# Parse proxy URL: http://user:pass@host:port
m = re.match(r'https?://(?:([^@]+)@)?([^:]+):(\d+)', proxy_url)
if not m:
    print('setup-docker: cannot parse https_proxy', file=sys.stderr)
    sys.exit(1)

auth, host, port = m.group(1), m.group(2), int(m.group(3))

# Connect through the CONNECT proxy to any HTTPS host
sock = socket.create_connection((host, port), timeout=10)
connect_req = f'CONNECT dl-cdn.alpinelinux.org:443 HTTP/1.1\r\nHost: dl-cdn.alpinelinux.org:443\r\n'
if auth:
    import base64
    connect_req += f'Proxy-Authorization: Basic {base64.b64encode(auth.encode()).decode()}\r\n'
connect_req += '\r\n'
sock.sendall(connect_req.encode())

resp = b''
while b'\r\n\r\n' not in resp:
    resp += sock.recv(4096)

if b'200' not in resp.split(b'\r\n')[0]:
    print(f'setup-docker: CONNECT failed: {resp.split(chr(13).encode())[0]}',
          file=sys.stderr)
    sys.exit(1)

# TLS handshake — get the server certificate chain
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
tls = ctx.wrap_socket(sock, server_hostname='dl-cdn.alpinelinux.org')
chain = tls.getpeercert_chain_pem()
tls.close()

# The last cert in the chain is the CA
if chain:
    ca_pem = chain[-1] if isinstance(chain, list) else chain
    with open('$PROXY_CA_PEM', 'w') as f:
        f.write(ca_pem if isinstance(ca_pem, str) else ca_pem.decode())
    print(f'setup-docker: wrote proxy CA to $PROXY_CA_PEM')
else:
    print('setup-docker: no cert chain returned', file=sys.stderr)
    sys.exit(1)
" && return 0
    fi

    echo "setup-docker: WARNING — could not extract proxy CA" >&2
    echo "setup-docker: builds through the proxy may fail TLS verification" >&2
    return 1
}

# ── 3. Configure Docker proxy ─────────────────────────────────────────────
configure_docker_proxy() {
    mkdir -p "$DOCKER_CONFIG_DIR"

    if [ -f "$DOCKER_CONFIG_DIR/config.json" ] && \
       grep -q '"proxies"' "$DOCKER_CONFIG_DIR/config.json" 2>/dev/null; then
        echo "setup-docker: Docker proxy config already present"
        return 0
    fi

    local http_proxy_val="${http_proxy:-${HTTP_PROXY:-}}"
    local https_proxy_val="${https_proxy:-${HTTPS_PROXY:-}}"

    if [ -z "$http_proxy_val" ] && [ -z "$https_proxy_val" ]; then
        echo "setup-docker: no proxy env vars set, skipping proxy config"
        return 0
    fi

    cat > "$DOCKER_CONFIG_DIR/config.json" <<JSONEOF
{
  "proxies": {
    "default": {
      "httpProxy": "${http_proxy_val}",
      "httpsProxy": "${https_proxy_val}",
      "noProxy": "127.0.0.1,localhost"
    }
  }
}
JSONEOF
    echo "setup-docker: wrote Docker proxy config"
}

# ── 4. Build wrapper with CA injection ────────────────────────────────────
#
# Docker has NO daemon-level mechanism to inject CA certificates into build
# containers (unlike resolv.conf which has special handling).  BuildKit's
# buildkitd.toml CA config only affects registry connections, not operations
# inside RUN commands (apk add, curl, git clone, etc.).
#
# This wrapper transparently transforms the Dockerfile to inject the proxy
# CA certificate after each FROM line, then runs the build with --network=host.
docker-build() {
    local dockerfile="Dockerfile"
    local args=()
    local has_network=false
    local has_file=false
    local skip_next=false

    # Parse arguments to find -f/--file and --network
    for arg in "$@"; do
        if $skip_next; then
            skip_next=false
            continue
        fi
        case "$arg" in
            -f|--file)
                has_file=true
                # Next argument is the dockerfile path — grab it via shift trick
                ;;
            --file=*)
                has_file=true
                dockerfile="${arg#--file=}"
                ;;
            --network|--network=*)
                has_network=true
                args+=("$arg")
                ;;
            *)
                args+=("$arg")
                ;;
        esac
    done

    # Second pass to extract -f value (need to handle "-f <path>" pairs)
    local prev=""
    for arg in "$@"; do
        if [ "$prev" = "-f" ] || [ "$prev" = "--file" ]; then
            dockerfile="$arg"
            prev=""
            continue
        fi
        prev="$arg"
    done

    # Rebuild args without -f and its value
    args=()
    skip_next=false
    for arg in "$@"; do
        if $skip_next; then
            skip_next=false
            continue
        fi
        case "$arg" in
            -f|--file)
                skip_next=true
                continue
                ;;
            --file=*)
                continue
                ;;
            *)
                args+=("$arg")
                ;;
        esac
    done

    # If no proxy CA, just run docker build directly
    if [ ! -f "$PROXY_CA_PEM" ]; then
        echo "setup-docker: no proxy CA found, running plain docker build" >&2
        local network_args=()
        if ! $has_network; then
            network_args=(--network=host)
        fi
        docker build -f "$dockerfile" "${network_args[@]}" "${args[@]}"
        return
    fi

    # Generate a transformed Dockerfile with CA injection
    local tmp_dockerfile
    tmp_dockerfile=$(mktemp /tmp/Dockerfile.ca-inject.XXXXXX)

    # Find the build context directory (last non-flag argument)
    local context_dir="."
    for a in "${args[@]}"; do
        if [[ "$a" != -* ]] && [ -d "$a" ]; then
            context_dir="$a"
        fi
    done

    # Copy the proxy CA to the build context if not already there
    local ca_in_context="$context_dir/proxy-ca.pem"
    local ca_copied=false
    if [ ! -f "$ca_in_context" ]; then
        cp "$PROXY_CA_PEM" "$ca_in_context"
        ca_copied=true
    fi

    # Transform the Dockerfile: after each FROM line, inject CA cert installation
    python3 -c "
import re, sys

with open('$dockerfile', 'r') as f:
    lines = f.readlines()

ca_injection = '''
# [AUTO-INJECTED] Install proxy CA certificate into trust store
COPY proxy-ca.pem /usr/local/share/ca-certificates/proxy-ca.crt
RUN cat /usr/local/share/ca-certificates/proxy-ca.crt >> /etc/ssl/certs/ca-certificates.crt
'''

result = []
for line in lines:
    result.append(line)
    # After each FROM line (but not comments), inject the CA
    stripped = line.strip()
    if stripped and not stripped.startswith('#') and re.match(r'FROM\s+', stripped, re.IGNORECASE):
        result.append(ca_injection)

with open('$tmp_dockerfile', 'w') as f:
    f.writelines(result)
"

    # Build with the transformed Dockerfile
    local network_args=()
    if ! $has_network; then
        network_args=(--network=host)
    fi

    docker build -f "$tmp_dockerfile" "${network_args[@]}" "${args[@]}"
    local rc=$?

    # Clean up
    rm -f "$tmp_dockerfile"
    if $ca_copied; then
        rm -f "$ca_in_context"
    fi

    return $rc
}

# ── Main setup ─────────────────────────────────────────────────────────────
setup_docker() {
    echo "=== Docker setup for Claude Code web agent ==="
    setup_dockerd
    extract_proxy_ca
    configure_docker_proxy
    echo "=== Docker setup complete ==="
    echo ""
    echo "Use 'docker-build' instead of 'docker build' to automatically"
    echo "inject the proxy CA certificate into Dockerfiles."
    echo "Example: docker-build --target test -t myimage ."
}

# Auto-run setup when sourced (but not when invoked as a script being read)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_docker
fi
