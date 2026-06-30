#!/usr/bin/env bash
# sdd-record-close.sh — Record the close commit SHA in review.md frontmatter
# Usage:
#   sdd-record-close.sh <feature>                  — record current HEAD
#   sdd-record-close.sh --sha <sha> <feature>      — record an explicit commit
#   sdd-record-close.sh --commit <feature>         — commit the review.md update

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FEATURE_ROOT=".features"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "record-close" "sdd record-close [--commit] [--sha <sha>] <feature>" "invalid shared CLI flags"
set -- "${SDD_ARGS[@]+"${SDD_ARGS[@]}"}"

show_help() {
  local flags_json
  flags_json="$(jq -nc --argjson common "$(sdd_common_flags_json)" '$common + [
    {"name":"--commit","description":"Commit the review.md close record after writing it"},
    {"name":"--sha <sha>","description":"Record an explicit commit instead of HEAD"}
  ]')"

  if sdd_is_json_mode; then
    sdd_help_json \
      "record-close" \
      "Record a close commit SHA and author date in a feature review.md frontmatter." \
      "sdd record-close [--commit] [--sha <sha>] <feature> [--feature <id|auto>] [--format text|json]" \
      "$flags_json" \
      '[]' \
      '[
        "sdd record-close 0001-user-auth",
        "sdd record-close --sha abc1234 0001-user-auth",
        "sdd record-close --commit --feature auto"
      ]'
    return 0
  fi

  echo "Usage: sdd record-close [--commit] [--sha <sha>] <feature>"
  echo ""
  echo "Record a close commit SHA and author date in review.md frontmatter."
  echo ""
  echo "Options:"
  echo "  --commit      Commit the review.md close record after writing it"
  echo "  --sha <sha>   Record an explicit commit instead of HEAD"
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }
sdd_install_cleanup_trap

# --- Argument parsing ---

RECORD_COMMIT=0
OVERRIDE_SHA=""
FEATURE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --commit)
      RECORD_COMMIT=1
      shift
      ;;
    --sha)
      shift
      [ -n "${1:-}" ] || sdd_usage_error "record-close" "sdd record-close [--commit] [--sha <sha>] <feature>" "--sha requires a value"
      OVERRIDE_SHA="$1"
      shift
      ;;
    -*)
      sdd_usage_error "record-close" "sdd record-close [--commit] [--sha <sha>] <feature>" "unknown option '$1'"
      ;;
    *)
      if [ -n "$FEATURE" ]; then
        sdd_usage_error "record-close" "sdd record-close [--commit] [--sha <sha>] <feature>" "only one feature may be specified"
      fi
      FEATURE="$1"
      shift
      ;;
  esac
done

if [ -z "$FEATURE" ] && [ -z "${SDD_FEATURE_OVERRIDE:-}" ]; then
  sdd_usage_error "record-close" "sdd record-close [--commit] [--sha <sha>] <feature>" "feature is required"
fi

FEATURE="${SDD_FEATURE_OVERRIDE:-$FEATURE}"
sdd_resolve_feature_target "$FEATURE" "$(sdd_is_machine_mode && echo 1 || echo 0)" || {
  case "$SDD_RESOLUTION_STATUS" in
    not_found)
      sdd_fail "record-close" "not_found" "feature '$FEATURE' not found" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "arg"
      ;;
    ambiguous)
      sdd_fail "record-close" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')" "" "auto"
      ;;
    none)
      sdd_usage_error "record-close" "sdd record-close [--commit] [--sha <sha>] <feature>" "feature is required"
      ;;
  esac
}
FEATURE="$SDD_RESOLVED_FEATURE"

FEATURE_DIR="$FEATURE_ROOT/$FEATURE"

if [ ! -d "$FEATURE_DIR" ]; then
  sdd_fail "record-close" "not_found" "feature directory '$FEATURE_DIR' not found" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

REVIEW_FILE="$FEATURE_DIR/review.md"

verify_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    sdd_fail "record-close" "precondition" "not inside a git work tree; cannot record close commit" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi
}

frontmatter_field_count() {
  local file="$1" key="$2"
  awk -v key="$key" '
    BEGIN { in_frontmatter=0; started=0; count=0 }
    $0 == "---" {
      if (!started) { started=1; in_frontmatter=1; next }
      if (in_frontmatter) { print count; exit }
    }
    in_frontmatter && $0 ~ "^" key ":[[:space:]]*" { count++ }
    END { if (!started) print 0 }
  ' "$file"
}

WRITE_CHANGED=0

write_close_record() {
  local file="$1" sha="$2" closed_at="$3"
  local current_sha current_closed_at commit_count closed_at_count tmp

  current_sha="$(sdd_frontmatter_value "$file" close_commit || true)"
  current_closed_at="$(sdd_frontmatter_value "$file" closed_at || true)"
  commit_count="$(frontmatter_field_count "$file" close_commit)"
  closed_at_count="$(frontmatter_field_count "$file" closed_at)"

  if [ "$current_sha" = "$sha" ] && [ "$current_closed_at" = "$closed_at" ] && [ "$commit_count" = "1" ] && [ "$closed_at_count" = "1" ]; then
    WRITE_CHANGED=0
    return 0
  fi

  tmp="$(sdd_tmp_for_target "$file")" || {
    sdd_fail "record-close" "precondition" "could not create temporary file for review.md" "{\"feature\":\"$FEATURE\",\"path\":\"$file\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
  }
  sdd_cleanup_push "$tmp"

  awk -v sha="$sha" -v closed_at="$closed_at" '
    BEGIN {
      in_frontmatter=0
      started=0
      closed=0
      saw_close_commit=0
      saw_closed_at=0
    }
    $0 == "---" {
      if (!started) {
        started=1
        in_frontmatter=1
        print
        next
      }
      if (in_frontmatter) {
        if (!saw_close_commit) print "close_commit: " sha
        if (!saw_closed_at) print "closed_at: " closed_at
        in_frontmatter=0
        closed=1
        print
        next
      }
    }
    in_frontmatter && /^close_commit:[[:space:]]*/ {
      if (!saw_close_commit) print "close_commit: " sha
      saw_close_commit=1
      next
    }
    in_frontmatter && /^closed_at:[[:space:]]*/ {
      if (!saw_closed_at) print "closed_at: " closed_at
      saw_closed_at=1
      next
    }
    { print }
    END {
      if (!closed) exit 2
    }
  ' "$file" > "$tmp" || {
    sdd_cleanup_file "$tmp"
    sdd_fail "record-close" "precondition" "could not update review.md frontmatter" "{\"feature\":\"$FEATURE\",\"path\":\"$file\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
  }

  if ! sdd_atomic_replace "$tmp" "$file"; then
    sdd_cleanup_file "$tmp"
    sdd_fail "record-close" "precondition" "could not replace review.md after recording close commit" "{\"feature\":\"$FEATURE\",\"path\":\"$file\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi

  WRITE_CHANGED=1
}

commit_close_record() {
  local file="$1" sha="$2"
  local short_sha subject body output_file add_exit commit_exit output

  short_sha="$(printf '%s' "$sha" | cut -c1-7)"
  subject="chore(${FEATURE}): record close sha ${short_sha}"
  body="$(printf 'Close-Commit: %s\nRefs: %s\n' "$sha" "$file")"
  output_file="$(mktemp "${TMPDIR:-/tmp}/sdd-record-close-commit.XXXXXX")"
  sdd_cleanup_push "$output_file"

  set +e
  git add -- "$file" >"$output_file" 2>&1
  add_exit=$?
  if [ "$add_exit" -eq 0 ]; then
    git commit --only -m "$subject" -m "$body" -- "$file" >>"$output_file" 2>&1
    commit_exit=$?
  else
    commit_exit=$add_exit
  fi
  set -e

  if [ "$commit_exit" -ne 0 ]; then
    output="$(cat "$output_file" 2>/dev/null || true)"
    sdd_cleanup_file "$output_file"
    sdd_fail "record-close" "blocked" "could not create close-record commit" "$(jq -nc --arg feature "$FEATURE" --arg path "$file" --arg output "$output" '{feature:$feature, path:$path, output:$output}')" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi

  FOLLOW_UP_SHA="$(git rev-parse HEAD)"
  sdd_cleanup_file "$output_file"
}

if [ ! -f "$REVIEW_FILE" ]; then
  sdd_fail "record-close" "precondition" "review.md is missing for feature '$FEATURE'" "{\"feature\":\"$FEATURE\",\"path\":\"$REVIEW_FILE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

verify_git_repo
if [ -n "$OVERRIDE_SHA" ]; then
  if ! CLOSE_COMMIT="$(git rev-parse --verify "${OVERRIDE_SHA}^{commit}" 2>/dev/null)"; then
    sdd_fail "record-close" "precondition" "invalid close commit SHA or ref '$OVERRIDE_SHA'" "$(jq -nc --arg feature "$FEATURE" --arg sha "$OVERRIDE_SHA" '{feature:$feature, sha:$sha}')" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi
else
  if ! CLOSE_COMMIT="$(git rev-parse HEAD 2>/dev/null)"; then
    sdd_fail "record-close" "precondition" "git HEAD is not available; cannot record close commit" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi
fi

if ! CLOSED_AT="$(git log -1 --format=%cs "$CLOSE_COMMIT" 2>/dev/null)"; then
  sdd_fail "record-close" "precondition" "could not read author date for close commit '$CLOSE_COMMIT'" "$(jq -nc --arg feature "$FEATURE" --arg sha "$CLOSE_COMMIT" '{feature:$feature, sha:$sha}')" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi
if [ -z "$CLOSED_AT" ]; then
  sdd_fail "record-close" "precondition" "close commit '$CLOSE_COMMIT' has no author date" "$(jq -nc --arg feature "$FEATURE" --arg sha "$CLOSE_COMMIT" '{feature:$feature, sha:$sha}')" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

write_close_record "$REVIEW_FILE" "$CLOSE_COMMIT" "$CLOSED_AT"
CHANGED="$WRITE_CHANGED"
COMMITTED=0
FOLLOW_UP_SHA=""

if [ "$RECORD_COMMIT" -eq 1 ] && [ "$CHANGED" -eq 1 ]; then
  commit_close_record "$REVIEW_FILE" "$CLOSE_COMMIT"
  COMMITTED=1
fi

DATA_JSON="$(jq -nc \
  --arg action "record-close" \
  --arg feature "$FEATURE" \
  --arg close_commit "$CLOSE_COMMIT" \
  --arg closed_at "$CLOSED_AT" \
  --arg path "$REVIEW_FILE" \
  --argjson changed "$CHANGED" \
  --argjson committed "$COMMITTED" \
  --argjson follow_up_sha "$(sdd_json_string_or_null "$FOLLOW_UP_SHA")" \
  '{
    action: $action,
    feature: $feature,
    close_commit: $close_commit,
    closed_at: $closed_at,
    review: $path,
    changed: $changed,
    committed: $committed
  } + (if $follow_up_sha != null then {follow_up_sha: $follow_up_sha} else {} end)')"
GUIDANCE_JSON="$(sdd_json_guidance "review.md now carries the close commit pointer; if --commit was not used, decide whether to commit the review.md change separately." "record-close records the SHA it is given; it does not validate commit-message format." "do not use record-close as a substitute for the explicit close commit step.")"

if sdd_is_json_mode; then
  sdd_emit_json_selection "$(sdd_json_success "record-close" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}" "close" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
  exit 0
fi

cat <<EOF
Close commit recorded: $FEATURE
Review: $REVIEW_FILE
SHA: $CLOSE_COMMIT
Date: $CLOSED_AT
Changed: $CHANGED
Committed: $COMMITTED
EOF
if [ -n "$FOLLOW_UP_SHA" ]; then
  printf 'Follow-up commit: %s\n' "$FOLLOW_UP_SHA"
fi
