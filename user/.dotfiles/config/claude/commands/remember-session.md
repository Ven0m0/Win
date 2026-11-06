Checkpoint this session: store non-obvious, reusable lessons in ICM long-term memory.

Target 3-10 pertinent stores total. Store the lesson, not the play-by-play. One fact per call, one sentence each, covering *what*, *why*, and *outcome*. Always pair a problem with its resolution if both happened this session; never store a gap alone. Anchor in VCS: prefer PR numbers and branch names. Feature-branch SHAs drift on amend; if you cite one, include the commit title so it stays grep-able.

| Kind                         | Topic                  | Importance |
| ---------------------------- | ---------------------- | ---------- |
| Decision + reason            | `decisions-<project>`  | high       |
| Error + root cause + fix     | `errors-resolved`      | high       |
| User preference / correction | `preferences`          | critical   |
| Pattern or invariant found   | `review-patterns`      | high       |
| Significant work completed   | `context-<project>`    | high       |

`<project>` = current project name (e.g. `decisions-icm`).

Skip: facts derivable from code or `git log`, transient build state, anything already stored this session (on re-run, capture only the delta).

Run:

    icm.exe remember "<fact>" --topic <topic> --importance <level> [--keywords "k1,k2"]

Example:

    icm.exe remember "Fixed flaky test by using fake timers; race condition only appeared under CI load" --topic errors-resolved --importance high --keywords "tests,flaky"

End with a one-line recap.
