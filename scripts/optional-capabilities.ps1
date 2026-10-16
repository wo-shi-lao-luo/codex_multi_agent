# Shared installation advice only: no discovery, downloads or client configuration.

# Return the optional frontend recommendation for installer and setup callers.
# The message deliberately makes no claim about installed files or active Skills.
function Get-OptionalCapabilityGuidance {
  return 'Optional frontend enhancement: Impeccable (https://impeccable.style/tutorials/getting-started/). Not required. Install separately only with user approval; if already installed, reload/check that the Skill is available in the active client. This step does not detect, load or install Impeccable.'
}
