# Resurrection Thanker

This addon is largely functional but still gives a "block" error so it can't work automatically yet.

## Overview

Resurrection Thanker is a World of Warcraft addon designed to automatically thank healers when they resurrect your character. It enhances gameplay by providing a polite and customizable way to express gratitude, fostering better community interactions in groups and raids.

## How It Works

The addon monitors the game's combat log for resurrection events targeting the player. When a resurrection spell is successfully cast on you, the addon triggers one of two response modes:

### Manual Mode (Default)

- Displays a popup window with up to 5 customizable thank-you message buttons.
- The popup includes a countdown timer (configurable from 5-60 seconds) after which it automatically disappears.
- Clicking a button sends the selected message to the chosen chat channel and closes the popup.
- The popup shows the name of the healer who resurrected you.

### Auto-Reply Mode

- Automatically sends a predefined thank-you message without showing the popup.
- The message is sent after a short delay to ensure the resurrection takes effect.

## Configuration

Access the configuration interface by:

- Typing `/rzt` or `/rezthanker` in the chat window
- Opening the Settings panel (Interface > AddOns > Resurrection Thanker)

### Available Settings

- **Auto-reply**: Toggle between manual popup and automatic message sending
- **Chat Channel**: Choose where messages are sent (Say, Party, Raid, or Whisper to the healer)
- **Popup Timeout**: Set how long the popup remains visible (5-60 seconds)
- **Messages**: Customize up to 5 thank-you messages using `%s` as a placeholder for the healer's name
- **Auto-Message Selection**: Choose which message to use for auto-reply

### Slash Commands

- `/rzt` or `/rzt config`: Open the configuration window
- `/rzt help`: Display available commands
- `/rzt auto on/off`: Toggle auto-reply
- `/rzt channel <say/party/raid/whisper>`: Set chat channel
- `/rzt timeout <5-60>`: Set popup timeout in seconds
- `/rzt automsg <1-5>`: Set which message to use for auto-reply
- `/rzt test`: Simulate a resurrection for testing
- `/rzt status`: Display current settings

## Supported Resurrection Spells

The addon recognizes the following resurrection spells:

- Resurrection (Priest)
- Raise Ally (Death Knight)
- Rebirth (Druid)
- Revive (Druid, out-of-combat)
- Redemption (Paladin)
- Ancestral Spirit (Shaman)
- Soulstone Resurrection (Warlock)
- Resuscitate (Monk)
- Return (Evoker)
- Revive (generic non-combat)
- Defibrillate

## Technical Details

- **Saved Variables**: Settings are stored in `ResurrectionThankerDB`
- **Interface Version**: Compatible with WoW interface version 120001 (likely Dragonflight)
- **Addon Files**:
  - `ResurrectionThanker.lua`: Main addon code
  - `ResurrectionThanker.toc`: Addon metadata and file list

The addon uses a taint-free custom UI to avoid conflicts with the game's interface, ensuring stability and compatibility.</content>
<parameter name="filePath">/usr/local/palermo/GIT/ResurrectionThanker/README.md
