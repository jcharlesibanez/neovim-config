-- Status hooks for Claude Code and Codex, so their badges know when each is working, done, or
-- waiting for your approval — whether you started it in the panel (<leader>cc / <leader>co) or
-- yourself in the <leader>t shell.
--
-- They're kept in the agents' own global settings, merged next to your other hooks:
--   ~/.claude/settings.json   (Claude Code)
--   ~/.codex/hooks.json       (Codex; trust them once in Codex's /hooks screen)
-- Each hook only does something inside a Neovim terminal (it checks $NVIM) and is silent
-- everywhere else. Neovim re-checks them on start and only writes a file if something changed;
-- the first change saves a backup next to it (*.before-dreamcore).
local M = {}

-- The shell command a hook runs: tell this Neovim (over $NVIM) what the agent is doing and
-- where it was started (the panel sets DREAM_AGENT_SOURCE=panel; otherwise it's the shell).
local function report(agent, state)
  return ('[ -n "$NVIM" ] && nvim --server "$NVIM" --remote-expr '
    .. '"v:lua.dream_agent_state(\'%s\', \'%s\', \'${DREAM_AGENT_SOURCE:-shell}\')" >/dev/null 2>&1; true')
    :format(state, agent)
end

local function hook(agent, state, matcher)
  local group = { hooks = { { type = 'command', command = report(agent, state), timeout = 5 } } }
  if matcher then group.matcher = matcher end
  return { group }
end

local function claude_hooks()
  return {
    SessionStart = hook('claude', 'session'),
    UserPromptSubmit = hook('claude', 'start'),
    Notification = hook('claude', 'attention', 'permission_prompt'),
    PostToolUse = hook('claude', 'working', '*'), -- you approved and the tool ran: back to work
    Stop = hook('claude', 'done'),
    SessionEnd = hook('claude', 'ended'),
  }
end

local function codex_hooks()
  return {
    SessionStart = hook('codex', 'session'),
    UserPromptSubmit = hook('codex', 'start'),
    PermissionRequest = hook('codex', 'attention'),
    PostToolUse = hook('codex', 'working'),
    Stop = hook('codex', 'done'),
    Interrupt = hook('codex', 'idle'),
    SessionEnd = hook('codex', 'ended'),
  }
end

-- Merge our hooks into a settings file, keeping everything else exactly as it is (key order,
-- types, other hooks). Our old entries are recognised by "dream_agent_state" and replaced.
-- Python's json keeps key order and the difference between {} and [], which Lua's can't.
local MERGE = [[
import json, os, shutil, sys
path, ours = os.path.expanduser(sys.argv[1]), json.loads(sys.argv[2])
data = {}
if os.path.exists(path):
    with open(path) as f: data = json.load(f)
before = json.dumps(data, sort_keys=True)
hooks = data.setdefault('hooks', {})
for event in list(hooks):
    hooks[event] = [g for g in hooks[event] if 'dream_agent_state' not in json.dumps(g)]
    if not hooks[event]: del hooks[event]
for event, groups in ours.items():
    hooks.setdefault(event, []).extend(groups)
if json.dumps(data, sort_keys=True) == before:
    print('unchanged'); sys.exit(0)
os.makedirs(os.path.dirname(path), exist_ok=True)
if os.path.exists(path) and not os.path.exists(path + '.before-dreamcore'):
    shutil.copy2(path, path + '.before-dreamcore')
tmp = '%s.tmp.%d' % (path, os.getpid())  # own temp file: two Neovims starting at once don't collide
with open(tmp, 'w') as f: json.dump(data, f, indent=2, ensure_ascii=False); f.write('\n')
os.replace(tmp, path)
print('updated')
]]

local function merge(path, hooks, cb)
  vim.system({ 'python3', '-c', MERGE, path, vim.json.encode(hooks) }, { text = true }, function(res)
    if cb then vim.schedule(function() cb(res.code == 0 and vim.trim(res.stdout or '') or ('error: ' .. (res.stderr or ''))) end) end
  end)
end

-- Make sure both agents' global settings have our hooks (quietly; notes only when it changed).
function M.install(cb)
  if vim.fn.executable('python3') == 0 then return end
  local pending, results = 2, {}
  local function done(name)
    return function(r)
      results[name] = r
      if r == 'updated' and name == 'codex' then
        vim.notify('Codex status hooks updated: trust them once in Codex with /hooks.', vim.log.levels.INFO)
      elseif r:match('^error') then
        vim.notify(('Couldn\'t update %s status hooks: %s'):format(name, r), vim.log.levels.WARN)
      end
      pending = pending - 1
      if pending == 0 and cb then cb(results) end
    end
  end
  merge('~/.claude/settings.json', claude_hooks(), done('claude'))
  merge('~/.codex/hooks.json', codex_hooks(), done('codex'))
end

return M
