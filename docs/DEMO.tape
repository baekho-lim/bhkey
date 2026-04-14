# bhkey demo recording script
# Tool: VHS (https://github.com/charmbracelet/vhs)
# Requirements: macOS + external keyboard connected + bhkey installed
#
# Usage:
#   brew install vhs
#   vhs docs/DEMO.tape
#
# Output: docs/demo.gif

Output docs/demo.gif
Set FontSize 14
Set Width 900
Set Height 480
Set Theme "Dracula"
Set Padding 20

# Show version
Sleep 500ms
Type "bhkey version"
Sleep 300ms
Enter
Sleep 1s

# Check initial status
Type "bhkey status"
Sleep 300ms
Enter
Sleep 2s

# Apply mapping
Type "bhkey apply"
Sleep 300ms
Enter
Sleep 3s

# Verify mapping applied
Type "bhkey status"
Sleep 300ms
Enter
Sleep 2s
