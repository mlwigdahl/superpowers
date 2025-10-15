---
description: Load or reload superpower plugin details into context
---

Determine the plugin directory of the superpowers plugin.  This should be {CLAUDE_PLUGIN_ROOT}, but if that value is empty it is likely {USER_HOME_DIRECTORY}.claude/plugins/cache/superpowers.
Use the bash tool to concatenate the plugin directory with lib/initialize-skills.sh and run it.
If the initialize-skills.sh script did not run or errored, end the command here.  Otherwise, continue.
Read and follow skills/using-skills/SKILL.md.
Finally, read skills/using-skills/find-skills and then use that skill to find the initial list of available skills.
