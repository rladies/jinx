// Workspace check for the worker's one remaining local slash command
// (`shorten`). Global-team authorization for privileged commands now lives
// entirely in R (`cmd_authorize()`), since every command that needed it
// (feedback, questions) is now dispatched, not handled locally.
export function slack_is_organizer_workspace(env, teamId) {
  return Boolean(env.SLACK_ORGANIZER_TEAM_ID) && teamId === env.SLACK_ORGANIZER_TEAM_ID;
}
