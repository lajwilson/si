#!/usr/bin/env bash
# si.sh — Fast, readable, Linux-focused non-root inventory
# Auto-detects distro family and adapts package/service queries.
#
# DISCLAIMER: THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY ARISING FROM THE USE OF THIS SOFTWARE. USE AT YOUR OWN RISK.
# See LICENSE and README for full terms. MIT License.
#
# Usage: curl -fsSL https://raw.githubusercontent.com/lajwilson/si/main/si.sh | bash

set -u
export LC_ALL=C

# ── Colors (TTY only) ──────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'; CYAN=$'\033[0;36m'; RESET=$'\033[0m'
else
  BOLD=''; DIM=''; GREEN=''; YELLOW=''; CYAN=''; RESET=''
fi

section() { printf "\n${BOLD}${CYAN}── %s ──${RESET}\n" "$1"; }
kv()      { printf "  ${GREEN}%-14s${RESET} %s\n" "$1:" "$2"; }
warn()    { printf "  ${YELLOW}!${RESET} %s\n" "$1"; }

# ── Cache common values (speed) ──────────────────────────────────────────
HOSTNAME=$(hostname 2>/dev/null || echo unknown)
FQDN=$(hostname -f 2>/dev/null || echo "$HOSTNAME")
USER_NAME=$(id -un)
USER_ID=$(id -u)
GROUPS=$(groups)
UPTIME=$(uptime -p 2>/dev/null || uptime)
KERNEL=$(uname -r)
ARCH=$(uname -m)
UNAME=$(uname -a)

# ── Distro detection ─────────────────────────────────────────────────
detect_distro() {
  DISTRO_ID="unknown"
  DISTRO_NAME="Unknown Linux"
  DISTRO_VERSION=""
  PKG_FAMILY="other"

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_NAME="${PRETTY_NAME:-${NAME:-Unknown}}"
    DISTRO_VERSION="${VERSION_ID:-}"
    ID_LIKE="${ID_LIKE:-}"

    case "$DISTRO_ID" in
      ubuntu|debian|linuxmint|pop|elementary|kali|raspbian) PKG_FAMILY="debian" ;;
      fedora|rhel|centos|rocky|almalinux|ol|amzn)         PKG_FAMILY="rhel" ;;
      arch|manjaro|endeavouros|artix)                      PKG_FAMILY="arch" ;;
      opensuse*|sles|sled)                                 PKG_FAMILY="suse" ;;
      alpine)                                              PKG_FAMILY="alpine" ;;
      gentoo)                                              PKG_FAMILY="gentoo" ;;
      *)
        case "$ID_LIKE" in
          *debian*) PKG_FAMILY="debian" ;;
          *rhel*|*fedora*|*centos*) PKG_FAMILY="rhel" ;;
          *arch*) PKG_FAMILY="arch" ;;
          *suse*) PKG_FAMILY="suse" ;;
        esac
        ;;
    esac
  fi

  # Fallback for minimal images
  if [[ "$PKG_FAMILY" == "other" ]]; then
    if command -v dpkg >/dev/null 2>&1; then PKG_FAMILY="debian"
    elif command -v rpm >/dev/null 2>&1; then PKG_FAMILY="rhel"
    elif command -v pacman >/dev/null 2>&1; then PKG_FAMILY="arch"
    elif command -v apk >/dev/null 2>&1; then PKG_FAMILY="alpine"
    fi
  fi
}
detect_distro

# ── At a Glance ───────────────────────────────────────────────────
section "At a Glance"
kv "Host"     "$HOSTNAME ($FQDN)"
kv "User"     "$USER_NAME (uid=$USER_ID)"
kv "Distro"   "$DISTRO_NAME [$PKG_FAMILY]"
kv "Kernel"   "$KERNEL ($ARCH)"
kv "Uptime"   "$UPTIME"

# ── Identity ────────────────────────────────────────────────────
section "Identity"
kv "Groups"   "$GROUPS"
kv "Home"     "$HOME"
kv "Shell"    "${SHELL:-unknown}"
kv "Date"     "$(date '+%Y-%m-%d %H:%M:%S %Z')"

# ── Hardware ────────────────────────────────────────────────────
section "CPU & Memory"
if [[ -r /proc/cpuinfo ]]; then
  model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | xargs)
  cores=$(grep -c '^processor' /proc/cpuinfo)
  kv "CPU" "${model:-unknown} ($cores logical)"
fi
if command -v free >/dev/null 2>&1; then
  free -h | awk 'NR==1 || NR==2 {printf "  • %s\n", $0}'
else
  awk '/MemTotal|MemAvailable|SwapTotal/ {print "  • " $0}' /proc/meminfo
fi

# Virt
if command -v systemd-detect-virt >/dev/null 2>&1; then
  kv "Virt" "$(systemd-detect-virt 2>/dev/null || echo none)"
elif grep -q hypervisor /proc/cpuinfo 2>/dev/null; then
  kv "Virt" "likely hypervisor"
elif [[ -r /proc/1/cgroup ]] && grep -qE 'docker|lxc|kubepods' /proc/1/cgroup 2>/dev/null; then
  kv "Virt" "container"
fi

# ── Disk ─────────────────────────────────────────────────────────
section "Disk & Mounts"
df -hT -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | awk 'NR==1 || $1 ~ /^\// {print "  • " $0}'
echo
printf "  ${GREEN}Notable mounts:${RESET}\n"
mount | grep -E '^(nfs|cifs|fuse|/dev)' | head -12 | sed 's/^/    /'

# ── Network ──────────────────────────────────────────────────
section "Network"
printf "  ${GREEN}Interfaces:${RESET}\n"
(ip -brief addr 2>/dev/null || ifconfig -a 2>/dev/null) | head -15 | sed 's/^/    /'
echo
printf "  ${GREEN}Default route:${RESET}\n"
(ip route show default 2>/dev/null || true) | sed 's/^/    /'
printf "  ${GREEN}DNS:${RESET}\n"
grep -E '^(nameserver|search|domain)' /etc/resolv.conf 2>/dev/null | sed 's/^/    /' || true

# ── Listening Ports ────────────────────────────────────────────────
section "Listening Ports"
if command -v ss >/dev/null 2>&1; then
  ss -tulnp 2>/dev/null | head -30 | sed 's/^/  /'
elif command -v netstat >/dev/null 2>&1; then
  netstat -tulnp 2>/dev/null | head -30 | sed 's/^/  /'
else
  warn "No ss or netstat"
fi

# ── Processes ───────────────────────────────────────────────────
section "Processes"
printf "  ${GREEN}Top by memory:${RESET}\n"
ps -eo user,pid,pcpu,pmem,rss,comm --sort=-pmem 2>/dev/null | awk 'NR==1 || NR<=18 {printf "    %s\n", $0}' || true

echo
printf "  ${GREEN}Notable processes:${RESET}\n"
ps -eo comm,args 2>/dev/null \
  | grep -E 'nginx|apache|httpd|caddy|mysqld|postgres|redis|mongo|docker|containerd|kubelet|java|node|php|gunicorn|uwsgi|celery|prometheus|grafana|node_exporter' \
  | grep -v grep | head -12 | sed 's/^/    /' || warn "None detected"

# ── Users ─────────────────────────────────────────────────────────
section "Users"
printf "  ${GREEN}Local users (uid ≥ 1000 or root):${RESET}\n"
awk -F: '$3 >= 1000 || $3 == 0 {printf "    %s (uid=%s) shell=%s\n", $1, $3, $7}' /etc/passwd 2>/dev/null

# ── Packages (distro-aware, limited for speed) ────────────────────────
section "Packages & Runtimes"
case "$PKG_FAMILY" in
  debian)
    if command -v dpkg >/dev/null 2>&1; then
      kv "Packages" "$(dpkg -l 2>/dev/null | grep -c '^ii') (debian)"
      dpkg -l 2>/dev/null | grep -E 'nginx|apache|mysql|postgres|docker|redis|mongo|java|python|node|php' \
        | awk '{print "    " $2 " " $3}' | head -12
    fi
    ;;
  rhel|suse)
    if command -v rpm >/dev/null 2>&1; then
      kv "Packages" "$(rpm -qa 2>/dev/null | wc -l) ($PKG_FAMILY)"
      rpm -qa 2>/dev/null | grep -E 'nginx|httpd|mysql|postgres|docker|redis|mongo|java|python|node|php' \
        | head -12 | sed 's/^/    /'
    fi
    ;;
  arch)
    if command -v pacman >/dev/null 2>&1; then
      kv "Packages" "$(pacman -Qq 2>/dev/null | wc -l) (arch)"
      pacman -Q 2>/dev/null | grep -E 'nginx|apache|mysql|postgres|docker|redis|mongo|java|python|node|php' \
        | head -12 | sed 's/^/    /'
    fi
    ;;
  alpine)
    if command -v apk >/dev/null 2>&1; then
      kv "Packages" "$(apk info 2>/dev/null | wc -l) (alpine)"
      apk info 2>/dev/null | grep -E 'nginx|apache|mysql|postgres|docker|redis|mongo|java|python|node|php' \
        | head -12 | sed 's/^/    /'
    fi
    ;;
  *)
    warn "No recognized package manager"
    ;;
esac

echo
printf "  ${GREEN}Runtimes:${RESET}\n"
for cmd in python3 python node java php go; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ver=$($cmd --version 2>/dev/null | head -1 | cut -c1-60)
    printf "    %s: %s\n" "$cmd" "$ver"
  fi
done

# ── Services & Containers ─────────────────────────────────────────────
section "Services & Containers"
if command -v systemctl >/dev/null 2>&1; then
  printf "  ${GREEN}Running systemd services:${RESET}\n"
  systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | head -15 | sed 's/^/    /' || true
elif command -v rc-status >/dev/null 2>&1; then
  printf "  ${GREEN}OpenRC services:${RESET}\n"
  rc-status 2>/dev/null | head -15 | sed 's/^/    /' || true
fi

if command -v docker >/dev/null 2>&1; then
  printf "  ${GREEN}Docker:${RESET}\n"
  docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null | head -10 | sed 's/^/    /' || warn "docker not usable"
fi
if command -v podman >/dev/null 2>&1; then
  printf "  ${GREEN}Podman:${RESET}\n"
  podman ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null | head -8 | sed 's/^/    /' || true
fi

# ── Cron & Env ───────────────────────────────────────────────────
section "Cron & Environment"
printf "  ${GREEN}User crontab:${RESET}\n"
crontab -l 2>/dev/null | head -10 | sed 's/^/    /' || printf "    (none)\n"

echo
printf "  ${GREEN}Key env:${RESET}\n"
env | grep -E '^(PATH|HOME|USER|SHELL|VIRTUAL_ENV|CONDA|JAVA_|NODE_|PYTHON|AWS_|KUBE|DOCKER)=' | sort | sed 's/^/    /'

# ── Purpose Hints ────────────────────────────────────────────────
section "Purpose Hints"
cat << 'EOF'
  Signals to look for:
    • 80/443 + nginx/apache/caddy     → web / reverse proxy
    • 3306/5432/6379/27017            → database
    • docker/containerd/kubelet       → container host
    • high-mem java/node              → app server
    • mostly sshd                     → bastion
    • node_exporter/grafana           → monitoring
EOF

echo
printf "${BOLD}${GREEN}Done.${RESET} Family: ${PKG_FAMILY}\n"