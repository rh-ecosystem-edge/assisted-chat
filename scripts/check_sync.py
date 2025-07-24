#!/usr/bin/env python3

# This script checks if the Containerfile in the assisted-chat directory
# is in sync with the Containerfile in the lightspeed-stack directory.

from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
ROOT_DIR = SCRIPT_DIR.parent

with open(ROOT_DIR / "Containerfile.assisted-chat", "r") as f:
    assisted_chat_containerfile = f.read()

with open(ROOT_DIR / "lightspeed-stack/Containerfile", "r") as f:
    lightspeed_stack_containerfile_original = f.read()

MARKER_CONTAINERFILE_START = "# <---------- START OF LIGHTSPEED-STACK CONTAINERFILE"
MARKER_CONTAINERFILE_END = "# <---------- END OF LIGHTSPEED-STACK CONTAINERFILE"

lightspeed_stack_containerfile_copy = assisted_chat_containerfile[
    assisted_chat_containerfile.index(MARKER_CONTAINERFILE_START)
    + len(MARKER_CONTAINERFILE_START)
    + 1 : assisted_chat_containerfile.index(MARKER_CONTAINERFILE_END)
]

print("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ Extracted copy:")
print(lightspeed_stack_containerfile_copy)

MARKER_MODIFIED_START = "# <---------- START ASSISTED-CHAT MODIFIED SECTION"
MARKER_MODIFIED_END = "# <---------- END ASSISTED-CHAT MODIFIED SECTION"

lightstack_stack_containerfile_copy_removed_modification = (
    lightspeed_stack_containerfile_copy[
        : lightspeed_stack_containerfile_copy.index(MARKER_MODIFIED_START) - 1
    ]
    + lightspeed_stack_containerfile_copy[
        lightspeed_stack_containerfile_copy.index(MARKER_MODIFIED_END)
        + len(MARKER_MODIFIED_END)
        + 1 :
    ]
)

print(
    "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ Extracted copy without modifications:"
)
print(lightstack_stack_containerfile_copy_removed_modification)

lightspeed_stack_containerfile_copy_fixed_copy_statements = lightstack_stack_containerfile_copy_removed_modification.replace(
    "COPY lightspeed-stack/src ./src", "COPY src ./src"
).replace(
    "COPY lightspeed-stack/pyproject.toml lightspeed-stack/LICENSE lightspeed-stack/README.md lightspeed-stack/uv.lock ./",
    "COPY pyproject.toml LICENSE README.md uv.lock ./",
)

print("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ Fixed copy statements:")
print(lightspeed_stack_containerfile_copy_fixed_copy_statements)

print(
    "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ Original Containerfile from lightspeed-stack:"
)
print(lightspeed_stack_containerfile_original)

assert (
    lightspeed_stack_containerfile_original
    == lightspeed_stack_containerfile_copy_fixed_copy_statements
), (
    "The Containerfile in the assisted-chat directory is not in sync with the "
    "Containerfile in the lightspeed-stack directory. Please update it."
)

print("Containerfiles are in sync.")
