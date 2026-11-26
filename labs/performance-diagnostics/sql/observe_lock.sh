#!/bin/sh
set -eu

export PGAPPNAME=perf_lab_waiter
PGOPTIONS='-c statement_timeout=10s' psql -X -q -U lab -d performance_diagnostics \
    -v ON_ERROR_STOP=1 -f /lab/sql/lock_waiter.sql &
waiter=$!
trap 'kill "$waiter" 2>/dev/null || true' EXIT

PGAPPNAME=perf_lab_observer psql -X -U lab -d performance_diagnostics \
    -v blocker_pid="$PERF_LAB_BLOCKER_PID" -f /lab/sql/lock_observer.sql
# O observador cancela o UPDATE. Com ON_ERROR_STOP, psql deve sair com código 3.
status=0
wait "$waiter" || status=$?
trap - EXIT
test "$status" -eq 3
