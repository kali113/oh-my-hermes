#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$(mktemp -d)"
trap 'rm -rf "$STATE"' EXIT

export OH_HERMES_STATE="$STATE"
"$ROOT/bin/oh-hermes" secretary init >/dev/null
default_routines="$("$ROOT/bin/oh-hermes" secretary routine list)"
grep -q "Daily Review" <<< "$default_routines"

agenda_file="$STATE/sample.ics"
inbox_file="$STATE/note.md"
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
cat > "$inbox_file" <<'MD'
Follow up with local context.
This should become a task.
MD

task_file="$("$ROOT/bin/oh-hermes" secretary task add --title "Test due task" --due 2000-01-01 --priority high --project smoke --body "verify task lifecycle")"
[[ -f "$task_file" ]]
inbox_item="$("$ROOT/bin/oh-hermes" secretary inbox import "$inbox_file" --title "Inbox smoke")"
[[ -f "$inbox_item" ]]
inbox_list="$("$ROOT/bin/oh-hermes" secretary inbox list)"
grep -q "Inbox smoke" <<< "$inbox_list"
triaged_task="$("$ROOT/bin/oh-hermes" secretary inbox triage --id "$(basename "$inbox_item" .md)" --to task --due 2000-01-02)"
[[ -f "$triaged_task" ]]
inbox_action_item="$("$ROOT/bin/oh-hermes" secretary inbox import "$inbox_file" --title "Inbox action smoke")"
triaged_action="$("$ROOT/bin/oh-hermes" secretary inbox triage --id "$(basename "$inbox_action_item" .md)" --to action --project smoke)"
[[ -f "$triaged_action" ]]
grep -q "Inbox action smoke" "$triaged_action"
decision_file="$("$ROOT/bin/oh-hermes" secretary decision add --title "Smoke decision" --body "Use private decision log")"
[[ -f "$decision_file" ]]
decision_list="$("$ROOT/bin/oh-hermes" secretary decision list)"
grep -q "Smoke decision" <<< "$decision_list"
decision_show="$("$ROOT/bin/oh-hermes" secretary decision show "$(basename "$decision_file" .md)")"
grep -q "Use private decision log" <<< "$decision_show"
action_file="$("$ROOT/bin/oh-hermes" secretary action add --title "Smoke action" --type code --risk medium --project smoke --requires-approval 1 --body "Propose worker action")"
[[ -f "$action_file" ]]
action_list="$("$ROOT/bin/oh-hermes" secretary action list)"
grep -q "Smoke action" <<< "$action_list"
grep -q "proposed" <<< "$action_list"
action_show="$("$ROOT/bin/oh-hermes" secretary action show "$(basename "$action_file" .md)")"
grep -q "Propose worker action" <<< "$action_show"
"$ROOT/bin/oh-hermes" secretary action approve "$(basename "$action_file" .md)" "Approved in smoke test" >/dev/null
action_list="$("$ROOT/bin/oh-hermes" secretary action list)"
grep -q "approved" <<< "$action_list"
session_file="$("$ROOT/bin/oh-hermes" secretary action start "$(basename "$action_file" .md)" "Start smoke worker session")"
[[ -f "$session_file" ]]
grep -q "Worker Session: Smoke action" "$session_file"
grep -q "Operating Rules" "$session_file"
action_list="$("$ROOT/bin/oh-hermes" secretary action list)"
grep -q "in_progress" <<< "$action_list"
session_list="$("$ROOT/bin/oh-hermes" secretary session list)"
grep -q "Smoke action" <<< "$session_list"
session_show="$("$ROOT/bin/oh-hermes" secretary session show "$(basename "$session_file" .md)")"
grep -q "Start smoke worker session" <<< "$session_show"
session_file_again="$("$ROOT/bin/oh-hermes" secretary action start "$(basename "$action_file" .md)")"
[[ "$session_file_again" == "$session_file" ]]
"$ROOT/bin/oh-hermes" secretary action done "$(basename "$action_file" .md)" "Completed in smoke test" >/dev/null
action_list="$("$ROOT/bin/oh-hermes" secretary action list)"
grep -vq "Smoke action" <<< "$action_list"
action_list_all="$("$ROOT/bin/oh-hermes" secretary action list --all)"
grep -q "done" <<< "$action_list_all"
session_list="$("$ROOT/bin/oh-hermes" secretary session list)"
grep -vq "Smoke action" <<< "$session_list"
session_list_all="$("$ROOT/bin/oh-hermes" secretary session list --all)"
grep -q "closed" <<< "$session_list_all"
learn_candidates="$("$ROOT/bin/oh-hermes" secretary learn list --status candidate)"
grep -q "Action outcome: Smoke action" <<< "$learn_candidates"
stale_task="$("$ROOT/bin/oh-hermes" secretary task add --title "Stale smoke task" --body "old task")"
stale_action="$("$ROOT/bin/oh-hermes" secretary action add --title "Stale smoke action" --requires-approval 0 --body "old action")"
stale_session_action="$("$ROOT/bin/oh-hermes" secretary action add --title "Stale smoke session" --requires-approval 0 --body "old session")"
stale_session="$("$ROOT/bin/oh-hermes" secretary action start "$(basename "$stale_session_action" .md)")"
touch -d '2 days ago' "$stale_task" "$stale_action" "$stale_session_action" "$stale_session"
sweep_file="$("$ROOT/bin/oh-hermes" secretary sweep --task-days 0 --action-days 0 --session-days 0)"
[[ -f "$sweep_file" ]]
grep -q "Stale smoke task" "$sweep_file"
grep -q "Stale smoke action" "$sweep_file"
grep -q "Stale smoke session" "$sweep_file"
grep -q "Candidate Lessons" "$sweep_file"
audit_file="$("$ROOT/bin/oh-hermes" secretary audit)"
[[ -f "$audit_file" ]]
grep -q "No consistency issues found" "$audit_file"
cat > "$STATE/secretary/sessions/orphan.md" <<'MD'
# Worker Session: Orphan

- Started: `2000-01-01T00:00:00Z`
- Status: `active`
- Action: `missing-action`

## Work Notes
MD
strict_audit="$STATE/strict-audit.out"
if "$ROOT/bin/oh-hermes" secretary audit --strict > "$strict_audit"; then
  echo "strict audit unexpectedly passed" >&2
  exit 1
fi
grep -q "references missing action" "$(tail -n 1 "$strict_audit")"
rm -f "$STATE/secretary/sessions/orphan.md"
action_plan="$("$ROOT/bin/oh-hermes" secretary action plan)"
[[ -f "$action_plan" ]]
focus_file="$("$ROOT/bin/oh-hermes" secretary focus)"
[[ -f "$focus_file" ]]
grep -q "Secretary Focus Queue" "$focus_file"
grep -q "Due And Overdue Tasks" "$focus_file"
grep -q "Test due task" "$focus_file"
grep -q "Stale smoke action" "$focus_file"
lesson_file="$("$ROOT/bin/oh-hermes" secretary learn add --title "Smoke lesson" --body "Remember smoke-test preference" --source smoke --confidence high)"
[[ -f "$lesson_file" ]]
learn_list="$("$ROOT/bin/oh-hermes" secretary learn list)"
grep -q "Smoke lesson" <<< "$learn_list"
learn_show="$("$ROOT/bin/oh-hermes" secretary learn show "$(basename "$lesson_file" .md)")"
grep -q "Remember smoke-test preference" <<< "$learn_show"
routine_file="$("$ROOT/bin/oh-hermes" secretary routine add --name "Smoke routine" --schedule daily --body "- [ ] Check smoke task")"
[[ -f "$routine_file" ]]
routine_list="$("$ROOT/bin/oh-hermes" secretary routine list)"
grep -q "Smoke routine" <<< "$routine_list"
routine_run="$("$ROOT/bin/oh-hermes" secretary routine run daily)"
grep -q "smoke-routine" <<< "$routine_run"
while IFS= read -r run_file; do
  [[ -f "$run_file" ]]
  grep -q "Routine Run" "$run_file"
  grep -q "Ran: \`" "$run_file"
  grep -q "Source: \`" "$run_file"
done <<< "$routine_run"

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
"$ROOT/bin/oh-hermes" secretary task done "$task_id" "Finished task in smoke test" >/dev/null
task_list_after="$("$ROOT/bin/oh-hermes" secretary task list)"
grep -vq "Test due task" <<< "$task_list_after"
task_list_all="$("$ROOT/bin/oh-hermes" secretary task list --all)"
grep -q "done" <<< "$task_list_all"
learn_candidates="$("$ROOT/bin/oh-hermes" secretary learn list --status candidate)"
grep -q "Task outcome: Test due task" <<< "$learn_candidates"
candidate_id="$(awk -F' \\| ' '/Action outcome: Smoke action/ {print $1; exit}' <<< "$learn_candidates")"
"$ROOT/bin/oh-hermes" secretary learn promote "$candidate_id" "Promote action learning in smoke test" >/dev/null
active_lessons="$("$ROOT/bin/oh-hermes" secretary learn list --status active)"
grep -q "Action outcome: Smoke action" <<< "$active_lessons"
"$ROOT/bin/oh-hermes" secretary learn archive "$(basename "$lesson_file" .md)" "Archive manual smoke lesson" >/dev/null
learn_review="$("$ROOT/bin/oh-hermes" secretary learn review)"
[[ -f "$learn_review" ]]
grep -q "Learning Review" "$learn_review"
brief_file="$("$ROOT/bin/oh-hermes" secretary brief)"
grep -q "Active Lessons" "$brief_file"
agent_status="$("$ROOT/bin/oh-hermes" agent status)"
grep -q "oh-hermes Agent Status" <<< "$agent_status"
agent_json="$("$ROOT/bin/oh-hermes" agent json)"
grep -q '"health"' <<< "$agent_json"
grep -q '"secretary"' <<< "$agent_json"
grep -q '"latest_reports"' <<< "$agent_json"
if command -v python3 >/dev/null 2>&1; then
  python3 -m json.tool <<< "$agent_json" >/dev/null
fi
"$ROOT/bin/oh-hermes" agent report >/dev/null
context_pack="$("$ROOT/bin/oh-hermes" agent context-pack)"
grep -q "Active Lessons" "$context_pack"
grep -q "Latest Maintenance Sweep" "$context_pack"
grep -q "Latest State Audit" "$context_pack"
grep -q "publish-check" "$ROOT/bin/oh-hermes"
