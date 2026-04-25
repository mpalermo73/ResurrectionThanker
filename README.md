# Resurrection Thanker

This addon thanks the player who resurrected you, either with a small confirmation popup or with an optional automatic chat message.

## Overview

Resurrection Thanker is a World of Warcraft addon designed to thank the player who resurrected your character. It provides a polite and customizable way to express gratitude in groups and raids.

## How It Works

The addon monitors party and raid spellcast events for resurrection spells targeting the player. When a resurrection completes, the addon triggers one of two response modes:

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
- `/rzt test`: Simulate a resurrection for testing
- `/rzt status`: Display current settings

## Supported Resurrection Spells

The addon recognizes the following resurrection spells:

- Resurrection (Priest)
- Ancestral Spirit (Shaman)
- Raise Ally (Death Knight)
- Rebirth (Druid)
- Revive (Druid, out-of-combat)
- Redemption (Paladin)
- Soulstone Resurrection (Warlock)
- Resuscitate (Monk)
- Return (Evoker)
- Revive (generic non-combat)
- Defibrillate

## Technical Details

- **Saved Variables**: Settings are stored in `ResurrectionThankerDB`
- **Interface Version**: Uses the interface version in `ResurrectionThanker.toc`
- **Addon Files**:
  - `ResurrectionThanker.lua`: Main addon code
  - `ResurrectionThanker.toc`: Addon metadata and file list

The addon uses Blizzard's modern Settings API for its configuration panel.
