#!/usr/bin/env bash
# Read-only snapshot of the local OpenBot database for the Omarchy bar widget.
#
# Nothing here writes to the database: sqlite3 opens it with -readonly, so a
# stale -wal can never be checkpointed away by this script. Any failure prints
# a JSON object with "ok": false instead of exiting non-zero, because the QML
# side treats a crashed poll as "app not running" and keeps the last state.
set -u

DB="${OPENBOT_DB:-${XDG_CONFIG_HOME:-$HOME/.config}/OpenBot/openbot.db}"

if [ ! -r "$DB" ]; then
  printf '{"ok":false,"error":"database-missing"}'
  exit 0
fi

sqlite3 -readonly -cmd ".timeout 750" "$DB" <<'SQL' 2>/dev/null || printf '{"ok":false,"error":"query-failed"}'
WITH
  now AS (SELECT CAST(strftime('%s','now') AS INTEGER) AS t),
  active AS (
    SELECT t.turn_id, t.thread_id, t.started_at,
           th.title AS thread_title, th.agent_id
    FROM projection_turns t
    JOIN projection_threads th ON th.thread_id = t.thread_id
    WHERE t.status = 'running'
  ),
  last_note AS (
    SELECT a.turn_id,
           (SELECT m.message_json
              FROM projection_thread_messages m
             WHERE m.turn_id = a.turn_id AND m.item_type = 'commentary'
             ORDER BY m.ordinal DESC LIMIT 1) AS j,
           (SELECT COUNT(*)
              FROM projection_thread_messages m
             WHERE m.turn_id = a.turn_id AND m.item_type = 'commentary') AS steps,
           (SELECT CAST(strftime('%s', MAX(m.created_at)) AS INTEGER)
              FROM projection_thread_messages m
             WHERE m.turn_id = a.turn_id AND m.item_type = 'commentary') AS at
    FROM active a
  ),
  pending AS (
    SELECT p.turn_id,
           json_extract(p.payload_json,'$.requestId') AS request_id,
           CAST(strftime('%s', p.created_at) AS INTEGER) AS asked_at
    FROM projection_thread_activities p
    WHERE p.activity_type = 'prompt.requested'
      AND NOT EXISTS (
        SELECT 1 FROM projection_thread_activities r
         WHERE r.activity_type = 'prompt.resolved'
           AND json_extract(r.payload_json,'$.requestId') = json_extract(p.payload_json,'$.requestId')
      )
      AND CAST(strftime('%s', p.created_at) AS INTEGER) > CAST(strftime('%s','now') AS INTEGER) - 86400
  ),
  recent AS (
    SELECT t.turn_id, t.thread_id, t.status, t.completed_at,
           CAST(strftime('%s', t.completed_at) AS INTEGER) AS ended_at
    FROM projection_turns t
    WHERE t.status IN ('completed','failed','interrupted')
      AND t.completed_at IS NOT NULL
      AND CAST(strftime('%s', t.completed_at) AS INTEGER) > CAST(strftime('%s','now') AS INTEGER) - 90
    ORDER BY t.completed_at DESC
    LIMIT 4
  )
SELECT json_object(
  'ok', 1,
  'v', 1,
  'now', (SELECT t FROM now),
  'agents', COALESCE((
    SELECT json_group_array(json_object(
      'turnId', a.turn_id,
      'agentId', a.agent_id,
      'name', COALESCE(json_extract(ag.agent_json,'$.name'), a.thread_title, 'Agent'),
      'thread', a.thread_title,
      'model', COALESCE(json_extract(ag.agent_json,'$.model'), ''),
      'hue', json_extract(ag.agent_json,'$.avatarHue'),
      'seed', COALESCE(json_extract(ag.agent_json,'$.avatarSeed'), a.agent_id),
      'avatarUrl', COALESCE(json_extract(ag.agent_json,'$.avatarUrl'), ''),
      'elapsed', (SELECT t FROM now) - CAST(strftime('%s', a.started_at) AS INTEGER),
      'steps', COALESCE(ln.steps, 0),
      'quiet', CASE WHEN ln.at IS NULL THEN (SELECT t FROM now) - CAST(strftime('%s', a.started_at) AS INTEGER)
                    ELSE (SELECT t FROM now) - ln.at END,
      'activity', COALESCE(
        substr(replace(replace(trim(json_extract(ln.j,'$.text')), char(10), ' '), char(13), ' '), 1, 220),
        ''
      )
    ))
    FROM active a
    LEFT JOIN projection_agents ag ON ag.agent_id = a.agent_id
    LEFT JOIN last_note ln ON ln.turn_id = a.turn_id
  ), json('[]')),
  'questions', COALESCE((
    SELECT json_group_array(json_object(
      'turnId', p.turn_id,
      'requestId', p.request_id,
      'agentId', COALESCE(q.agent_id, ''),
      'name', COALESCE(json_extract(ag.agent_json,'$.name'), q.title, 'Agent'),
      'thread', COALESCE(q.title, ''),
      'hue', json_extract(ag.agent_json,'$.avatarHue'),
      'seed', COALESCE(json_extract(ag.agent_json,'$.avatarSeed'), q.agent_id),
      'avatarUrl', COALESCE(json_extract(ag.agent_json,'$.avatarUrl'), ''),
      'age', (SELECT t FROM now) - p.asked_at,
      'text', COALESCE((
        SELECT substr(replace(replace(trim(json_extract(m.message_json,'$.text')), char(10), ' '), char(13), ' '), 1, 400)
          FROM projection_thread_messages m
         WHERE m.turn_id = p.turn_id AND m.item_type = 'question_prompt'
         ORDER BY m.ordinal DESC LIMIT 1), ''
      )
    ))
    FROM pending p
    LEFT JOIN projection_turns pt ON pt.turn_id = p.turn_id
    LEFT JOIN projection_threads q ON q.thread_id = pt.thread_id
    LEFT JOIN projection_agents ag ON ag.agent_id = q.agent_id
  ), json('[]')),
  'waits', COALESCE((
    SELECT json_group_array(json_object(
      'agentId', w.agent_id,
      'name', COALESCE(json_extract(ag.agent_json,'$.name'), 'Agent'),
      'note', substr(w.note, 1, 160),
      'age', (SELECT t FROM now) - CAST(strftime('%s', w.created_at) AS INTEGER)
    ))
    FROM agent_waits w
    LEFT JOIN projection_agents ag ON ag.agent_id = w.agent_id
    WHERE w.woken_at IS NULL
  ), json('[]')),
  'recent', COALESCE((
    SELECT json_group_array(json_object(
      'turnId', r.turn_id,
      'name', COALESCE(json_extract(ag.agent_json,'$.name'), th.title, 'Agent'),
      'thread', th.title,
      'status', r.status,
      'hue', json_extract(ag.agent_json,'$.avatarHue'),
      'seed', COALESCE(json_extract(ag.agent_json,'$.avatarSeed'), th.agent_id),
      'avatarUrl', COALESCE(json_extract(ag.agent_json,'$.avatarUrl'), ''),
      'ended', r.ended_at
    ))
    FROM recent r
    JOIN projection_threads th ON th.thread_id = r.thread_id
    LEFT JOIN projection_agents ag ON ag.agent_id = th.agent_id
  ), json('[]')),
  'counts', json_object(
    'running', (SELECT COUNT(*) FROM active),
    'questions', (SELECT COUNT(*) FROM pending),
    'waits', (SELECT COUNT(*) FROM agent_waits WHERE woken_at IS NULL),
    'recent', (SELECT COUNT(*) FROM recent)
  )
);
SQL
