# Annotation fix routine

Fix each requested change in the code. Open a pull request (PR) that
describes each fix. Stay on the PR. Watch it for comments and reply to them.

## Input

This turn's text is the batch: a JSON array of annotation objects. Parse it.
If the array is empty, say so. Stop.

### Annotation fields

| Field | Use |
|---|---|
| `id` | Stable id. Link each fix to its annotation in the PR body. |
| `note` | The requested change. This is the task. |
| `sourceLocation` | `file:line` of the widget. Check this first. |
| `screen` | Root widget type of the screen. The main grouping key. |
| `route` | Route name of the screen. `null` for unnamed routes. |
| `widgetType` | Runtime type of the target widget (e.g. `Text`, `ElevatedButton`). |
| `tappedWidgetRoute` | Path from the first tapped widget to the final target (e.g. `Card>Button>Icon`). It equals `widgetType` when the user picks the widget directly. |
| `widgetKey` | The widget's `Key` string, if any. An exact, searchable id. |
| `widgetOrdinal` / `widgetOrdinalCount` | Position "N of M" among same-type widgets, top-to-bottom then left-to-right. Use this when there is no key. |

## Workflow

1. Parse the input array.
2. If the array is empty, report "No annotations in this batch". Stop.
3. Group the annotations. See "Group the work".
4. Optional: track progress with the task board, one task per annotation id.
5. Dispatch one fix subagent per group. See "Fix subagent prompt".
6. Run independent groups in parallel.
7. Collect each subagent's report: the file:line changed, a one-line summary,
   and any annotation it could not locate.
8. Create a branch.
9. Commit the changes.
10. If the remote name is not `origin`, run `git remote -v` first.
11. Push the branch.
12. Open a PR with `gh pr create`.
13. Build the PR body from the collected reports. See "PR body".
14. Enable notifications on the PR. See "After the PR opens".

## Group the work

Read all annotations before you split the work. Group by `screen` first,
then by `widgetType` or `widgetKey`.

- Put related edits on one screen in one subagent. This avoids collisions.
- Give independent screens their own subagent. Dispatch these in parallel.
- A small batch across a few screens can stay one subagent.

Hard rule: two subagents must never edit the same file at the same time.

## Fix subagent prompt

Dispatch one `Agent` (`general-purpose`) per group with this prompt. Add the
annotation list for that group.

```
A user annotated one or more widgets in a Flutter app. Apply each requested
change to the code. The edit on disk is the deliverable.

Annotations in this group:
- id: <id>
  note (the requested change): "<note>"
  sourceLocation: <file:line, or "unknown">
  screen: <screen>   route: <route>
  widgetType: <widgetType>
  drillPath: <tappedWidgetRoute>
  widgetKey: <widgetKey, or "none">
  position: <widgetOrdinal> of <widgetOrdinalCount> same-type widgets on the screen
- (repeat for each annotation in this group)

Steps:
1. Locate the exact widget for each annotation. Try sourceLocation first. If
   it is missing or stale, search by screen and widgetType. Narrow the result
   with widgetKey or the ordinal position.
2. Apply the change the note asks for. Keep the edit small. Match the
   surrounding code style.
3. Run `flutter analyze` on the changed files. Fix any new issue you caused.
4. Report, for each annotation id: the file:line you changed, a one-line
   summary of the edit, and whether analyze is clean. If you could not
   locate a widget safely, say so. Do not guess. This report feeds the PR
   body.
```

## PR body

Map each annotation to its fix:

```
### <note>   (id: <id>)
- Annotated: <widgetType> on <screen> (<route>) at <sourceLocation, widgetKey, or ordinal>
- Fixed: <file:line> — <one-line description of the edit>
```

Group entries by screen when that matches the split of work. Add a short
summary line at the top (e.g. "N annotations across M screens. `flutter
analyze` clean."). List any annotation you could not locate under a **Not
fixed** heading, with the reason.

## After the PR opens

Stay engaged. Answer review feedback.

1. Get the repository name and PR number:
   `gh repo view --json nameWithOwner -q .nameWithOwner`
   `gh pr view --json number -q .number`
2. Enable notifications on the PR:
   `gh api -X PUT repos/<owner>/<repo>/issues/<pr_number>/subscription -f subscribed=true -f ignored=false`
3. Check for comments:
   - General comments: `gh pr view <pr_number> --comments`
   - Inline review comments: `gh api repos/<owner>/<repo>/pulls/<pr_number>/comments`
4. For each new comment:
   - If it asks for a code change, make the change. Commit it. Push it to
     the same branch. This updates the PR in place.
   - Reply to the comment. Use `gh pr comment <pr_number> --body "<reply>"`
     for a general reply. Reference the commit you pushed. For an inline
     comment, reply in its own thread with
     `gh api repos/<owner>/<repo>/pulls/<pr_number>/comments/<comment_id>/replies -f body="<reply>"`.
   - If a comment only asks a question, answer it in a reply. Do not push a
     commit for it.
5. Repeat step 3 and 4 while the routine runs.
