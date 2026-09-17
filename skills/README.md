# Agent skills for Cream CRM

Skills in this directory are for **CRM users and their AI agents**, not for developing the Cream app. Developer skills live under [`.claude/skills/`](../.claude/skills/).

## Install the `cream` skill

Copy or symlink the skill into your agent’s skills folder so the agent learns how to use Cream MCP tools.

**Cursor (personal — all projects):**

```bash
mkdir -p ~/.cursor/skills
cp -r skills/cream ~/.cursor/skills/cream
# or: ln -s "$(pwd)/skills/cream" ~/.cursor/skills/cream
```

**Cursor (single project):** copy `skills/cream` to `.cursor/skills/cream` in that project.

**Claude Code / other agents:** point the agent at `skills/cream/SKILL.md` or copy the folder to the path your client documents (e.g. `~/.claude/skills/cream`).

## Connect MCP

The skill assumes the **Cream MCP server** is configured (`POST …/mcp` with a `cream_` API token or OAuth). See [cream/setup.md](cream/setup.md).

End-user steps are also in [USER_MANUAL.md](../USER_MANUAL.md) (section «API tokens and MCP»).

## Contents

| Skill | Description |
|-------|-------------|
| [cream/](cream/SKILL.md) | Operate people, deals, tasks, pipeline, email, marketing via MCP |
