#!/bin/sh
# shellcheck shell=sh
qnd_effective_memory_bytes() {
  _qnd_cgroup=${QND_CGROUP_MEMORY_MAX_PATH:-/sys/fs/cgroup/memory.max}
  _qnd_meminfo=${QND_MEMINFO_PATH:-/proc/meminfo}
  if [ -r "$_qnd_cgroup" ]; then
    _qnd_limit=$(tr -d ' \t\r\n' < "$_qnd_cgroup" 2>/dev/null || true)
    case "$_qnd_limit" in
      ''|max|*[!0-9]*) : ;;
      *) if [ "$_qnd_limit" -gt 0 ] 2>/dev/null; then printf '%s\n' "$_qnd_limit"; return 0; fi ;;
    esac
  fi
  _qnd_kb=$(awk '/^MemTotal:/ {print $2; exit}' "$_qnd_meminfo" 2>/dev/null || true)
  case "$_qnd_kb" in ''|*[!0-9]*) echo 0 ;; *) echo $((_qnd_kb * 1024)) ;; esac
}

qnd_logical_cpus() {
  getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 1
}

qnd_physical_cores() {
  if command -v lscpu >/dev/null 2>&1; then
    _qnd_cps=$(lscpu -p=CORE,SOCKET 2>/dev/null | awk -F, '!/^#/ {print $1","$2}' | sort -u | wc -l | tr -d ' ')
    case "$_qnd_cps" in ''|0|*[!0-9]*) : ;; *) echo "$_qnd_cps"; return 0 ;; esac
  fi
  qnd_logical_cpus
}
