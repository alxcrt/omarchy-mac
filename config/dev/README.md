# Developer workflows

`mac dev` checks installed runtimes on the current PATH, Git, Docker/Compose, API and
database clients, and Docker Desktop, Bruno and DBeaver. It makes no server
connections and disables mise automatic installs for its version probes. A
missing or broken tool makes the check exit nonzero after finishing every check.
Use `mac dev help` to list the routes.

- `mac dev git status`, `diff`, `log` and `worktrees` show local repository
  information. An optional directory follows the action. `mac dev git ui`
  opens lazygit in the current repository; from elsewhere it offers repositories
  and worktrees up to three directory levels below `~/Developer` in fzf.
- `mac dev docker status`, `ps` and `compose` read the selected Docker context.
  Start Docker Desktop yourself if the engine is stopped. `mac dev docker ui`
  opens lazydocker, where container changes are explicit interactive actions.
- `mac dev db clients` checks PostgreSQL, Redis and SQLite client versions.
  `mac dev db open` opens DBeaver. The keg-only Homebrew libpq client is resolved
  explicitly when `psql` is absent from PATH.
- `mac dev api open` opens Bruno. Keep API collections in the project repository,
  and keep credentials in local untracked environments or the password manager.
  Use the existing `xh GET <url>` CLI for individual requests.
- `mac dev ports` lists listening TCP sockets; `mac dev ports 3000` narrows the
  query. It never stops the listener. lsof exits nonzero if nothing matches.

Use the project's own commands and lockfiles for application work: `pnpm dev`,
`pnpm test`, `uv run`, and `docker compose`. New runtimes and CLIs belong in mise;
system utilities and GUI apps belong in the Brewfile. Database connections,
project setup, migrations, container creation and service starts stay explicit.

The upstream reference is `omacom/omarchy` at `f4357a3` (17 October 2026):
`omarchy-install-dev-env` uses mise for the common runtimes and
`omarchy-launch-docker-tui` launches lazydocker. This Mac keeps those workflows
using its existing tools. It does not copy `omarchy-install-docker-dbs`, which
creates persistent containers and uses development authentication defaults;
project-owned Compose files are easier to review and reproduce.
