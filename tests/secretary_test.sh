#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$(mktemp -d)"
trap 'rm -rf "$STATE"' EXIT

export OH_HERMES_STATE="$STATE"

agenda_file="$STATE/sample.ics"
cat > "$agenda_file" <<'ICS'
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:test-event
DTSTART:20000101T090000Z
DTEND:20000101T100000Z
SUMMARY:Test calendar event
LOCATION:Local
END:VEVENT
END:VCALENDAR
ICS

task_file="$("$ROOT/bin/oh-hermes" secretary task add --title "Test due task" --due 2000-01-01 --priority high --project smoke --body "verify task lifecycle")"
[[ -f "$task_file" ]]

task_list="$("$ROOT/bin/oh-hermes" secretary task list)"
grep -q "Test due task" <<< "$task_list"
task_due="$("$ROOT/bin/oh-hermes" secretary task due)"
grep -q "Test due task" <<< "$task_due"
"$ROOT/bin/oh-hermes" secretary reminders >/dev/null
notify_status="$("$ROOT/bin/oh-hermes" secretary notify status)"
grep -q "enabled=" <<< "$notify_status"
"$ROOT/bin/oh-hermes" secretary notify enable-local >/dev/null
notify_status="$("$ROOT/bin/oh-hermes" secretary notify status)"
grep -q "enabled=1" <<< "$notify_status"
"$ROOT/bin/oh-hermes" secretary notify disable >/dev/null
agenda_import="$("$ROOT/bin/oh-hermes" secretary agenda import "$agenda_file")"
[[ -f "$agenda_import" ]]
feed_file="$("$ROOT/bin/oh-hermes" secretary agenda feed add --name smoke-agenda --source "$agenda_file")"
[[ -f "$feed_file" ]]
"$ROOT/bin/oh-hermes" secretary agenda feed list | grep -q "smoke-agenda"
"$ROOT/bin/oh-hermes" secretary agenda feed sync >/dev/null
agenda_list="$("$ROOT/bin/oh-hermes" secretary agenda list)"
grep -q "Test calendar event" <<< "$agenda_list"
"$ROOT/bin/oh-hermes" secretary integrations init >/dev/null
integration_status="$("$ROOT/bin/oh-hermes" secretary integrations status)"
grep -q "Email" <<< "$integration_status"
"$ROOT/bin/oh-hermes" secretary integrations plan >/dev/null

task_id="$(basename "$task_file" .md)"
"$ROOT/bin/oh-hermes" secretary task done "$task_id" >/dev/null
task_list_after="$("$ROOT/bin/oh-hermes" secretary task list)"
grep -vq "Test due task" <<< "$task_list_after"
task_list_all="$("$ROOT/bin/oh-hermes" secretary task list --all)"
grep -q "done" <<< "$task_list_all"
"$ROOT/bin/oh-hermes" secretary brief >/dev/null
agent_status="$("$ROOT/bin/oh-hermes" agent status)"
grep -q "oh-hermes Agent Status" <<< "$agent_status"
"$ROOT/bin/oh-hermes" agent report >/dev/null
"$ROOT/bin/oh-hermes" agent context-pack >/dev/null
grep -q "publish-check" "$ROOT/bin/oh-hermes"
